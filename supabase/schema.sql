-- Geteilte Historie für Flip 7. Einmal im SQL Editor des Supabase-Projekts ausführen.

create table public.games (
  id uuid primary key,
  finished_at timestamptz,
  data jsonb not null,
  deleted_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.player_resets (
  name_key text primary key,
  data jsonb not null,
  created_at timestamptz not null default now()
);

alter table public.games enable row level security;
alter table public.player_resets enable row level security;

-- Die App löscht nie, sondern setzt deleted_at. Darum gibt es keine delete-Policy.
grant select, insert, update on public.games, public.player_resets to anon;

create policy "App liest Spiele" on public.games for select to anon using (true);
create policy "App legt Spiele an" on public.games for insert to anon with check (true);
create policy "App ändert Spiele" on public.games for update to anon using (true) with check (true);

create policy "App liest Resets" on public.player_resets for select to anon using (true);
create policy "App legt Resets an" on public.player_resets for insert to anon with check (true);
create policy "App ändert Resets" on public.player_resets for update to anon using (true) with check (true);
