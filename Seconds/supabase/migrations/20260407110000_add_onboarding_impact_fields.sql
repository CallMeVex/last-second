alter table public.users
  add column if not exists daily_spending_estimate numeric,
  add column if not exists pornography_hours_per_day numeric,
  add column if not exists weekly_gambling_losses numeric;
