// RevenueCat → Supabase user subscription sync.
// Dashboard: Project Settings → Webhooks → URL: https://<project>.supabase.co/functions/v1/revenuecat-webhook
// Secrets: `supabase secrets set REVENUECAT_WEBHOOK_SECRET=your_secret` (same value as in RevenueCat webhook auth)
//         `SUPABASE_SERVICE_ROLE_KEY` is provided automatically in Edge Functions.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type RCEvent = {
  type?: string;
  app_user_id?: string;
  original_app_user_id?: string;
  product_id?: string | null;
  expiration_at_ms?: number | null;
};

type RCPayload = {
  api_version?: string;
  event?: RCEvent;
};

function verifyAuth(req: Request, secret: string): boolean {
  if (!secret) return false;
  const h = req.headers.get("Authorization")?.trim() ?? "";
  if (h === `Bearer ${secret}`) return true;
  if (h === secret) return true;
  return false;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const secret = Deno.env.get("REVENUECAT_WEBHOOK_SECRET") ?? "";
  if (!verifyAuth(req, secret)) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseUrl || !serviceKey) {
    return new Response(JSON.stringify({ error: "Server misconfigured" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const supabase = createClient(supabaseUrl, serviceKey);

  let body: RCPayload;
  try {
    body = (await req.json()) as RCPayload;
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const ev = body.event;
  if (!ev?.type) {
    return new Response(JSON.stringify({ ok: true, ignored: true }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const type = ev.type;
  const appUserId = ev.app_user_id?.trim();
  const originalAppUserId = ev.original_app_user_id?.trim() ?? appUserId;
  const productId = ev.product_id ?? null;
  const expMs = ev.expiration_at_ms ?? null;

  const positive = new Set([
    "INITIAL_PURCHASE",
    "RENEWAL",
    "UNCANCELLATION",
    "SUBSCRIBER_ALIAS",
    "NON_RENEWING_PURCHASE",
    "PRODUCT_CHANGE",
  ]);
  const negative = new Set([
    "EXPIRATION",
    "CANCELLATION",
    "BILLING_ISSUE",
    "SUBSCRIPTION_PAUSED",
  ]);

  let isSubscribed: boolean | null = null;
  let expiresIso: string | null = null;
  let productOut: string | null = null;
  let rcCustomerId: string | null = originalAppUserId ?? appUserId ?? null;

  if (positive.has(type)) {
    isSubscribed = true;
    if (expMs != null && expMs > 0) {
      expiresIso = new Date(expMs).toISOString();
    }
    productOut = productId;
  } else if (negative.has(type)) {
    isSubscribed = false;
    expiresIso = null;
    productOut = null;
  } else {
    return new Response(JSON.stringify({ ok: true, ignored: type }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const patch: Record<string, unknown> = {
    is_subscribed: isSubscribed,
    has_active_subscription: isSubscribed,
    revenuecat_customer_id: rcCustomerId,
    subscription_product_id: productOut,
    subscription_expires_at: expiresIso,
  };

  const matchIds = [appUserId, originalAppUserId].filter(
    (x): x is string => !!x && x.length > 0,
  );
  const unique = [...new Set(matchIds)];

  let updated = 0;
  for (const uid of unique) {
    const { data, error } = await supabase
      .from("users")
      .update(patch)
      .eq("id", uid)
      .select("id");
    if (error) {
      console.error("webhook update by id", uid, error);
    } else {
      updated += data?.length ?? 0;
    }
  }

  if (updated === 0 && originalAppUserId) {
    const { data, error } = await supabase
      .from("users")
      .update(patch)
      .eq("revenuecat_customer_id", originalAppUserId)
      .select("id");
    if (error) {
      console.error("webhook update by revenuecat_customer_id", error);
    } else {
      updated += data?.length ?? 0;
    }
  }

  return new Response(
    JSON.stringify({ ok: true, updated, event_type: type }),
    { headers: { ...corsHeaders, "Content-Type": "application/json" } },
  );
});
