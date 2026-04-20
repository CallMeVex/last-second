alter table public.users
  add column if not exists partner_id uuid references public.users(id) on delete set null,
  add column if not exists partnership_ended_notice boolean not null default false;

create table if not exists public.buddy_applications (
  id uuid primary key,
  user_id uuid not null unique references public.users(id) on delete cascade,
  addiction_type text not null,
  reason text not null,
  story text not null,
  streak integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.buddy_requests (
  id uuid primary key,
  sender_id uuid not null references public.users(id) on delete cascade,
  receiver_id uuid not null references public.users(id) on delete cascade,
  status text not null check (status in ('pending', 'accepted')),
  created_at timestamptz not null default now()
);

create table if not exists public.buddy_pairs (
  id uuid primary key,
  user1_id uuid not null references public.users(id) on delete cascade,
  user2_id uuid not null references public.users(id) on delete cascade,
  start_date date not null default current_date,
  combined_savings numeric not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists idx_buddy_requests_receiver on public.buddy_requests(receiver_id, status);
create index if not exists idx_buddy_pairs_user1 on public.buddy_pairs(user1_id);
create index if not exists idx_buddy_pairs_user2 on public.buddy_pairs(user2_id);
