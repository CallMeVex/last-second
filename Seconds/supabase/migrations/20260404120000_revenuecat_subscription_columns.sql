-- RevenueCat + Supabase subscription sync (client + webhook).
-- Run via Supabase SQL editor or `supabase db push`.

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS is_subscribed boolean NOT NULL DEFAULT false;

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS subscription_expires_at timestamptz;

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS revenuecat_customer_id text;

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS subscription_product_id text;

COMMENT ON COLUMN public.users.is_subscribed IS 'Premium active; updated by RevenueCat webhook and client sync.';
COMMENT ON COLUMN public.users.subscription_expires_at IS 'Premium entitlement expiration (from RevenueCat).';
COMMENT ON COLUMN public.users.revenuecat_customer_id IS 'RevenueCat original_app_user_id / subscriber id for webhook matching.';
COMMENT ON COLUMN public.users.subscription_product_id IS 'Active subscription product identifier from RevenueCat.';

-- Backfill from legacy column if it exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'has_active_subscription'
  ) THEN
    UPDATE public.users
    SET is_subscribed = true
    WHERE has_active_subscription = true AND is_subscribed = false;
  END IF;
END $$;
