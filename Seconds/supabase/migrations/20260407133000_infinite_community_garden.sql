alter table public.users
  add column if not exists recovery_quote text;

create table if not exists public.garden_trees (
  id uuid primary key,
  user_id uuid not null unique references public.users(id) on delete cascade,
  grid_x integer not null,
  grid_y integer not null,
  quote text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_garden_trees_grid on public.garden_trees(grid_x, grid_y);
create index if not exists idx_garden_trees_user on public.garden_trees(user_id);
