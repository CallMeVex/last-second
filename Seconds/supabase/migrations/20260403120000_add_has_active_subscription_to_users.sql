-- Premium is tied to this Supabase account. The app sets this on purchase and syncs with RevenueCat.
-- Run in Supabase SQL editor or via `supabase db push` if you use the CLI.

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS has_active_subscription boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.users.has_active_subscription IS
  'True when this account has an active in-app subscription (set on purchase; cleared when RevenueCat reports inactive).';
