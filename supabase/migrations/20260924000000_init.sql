-- ============================================================
--  PS-ARCADE global leaderboard schema
--  Run this once in the Supabase SQL editor (or `supabase db push`).
-- ============================================================

create table if not exists public.scores (
    id         bigint generated always as identity primary key,
    game       text        not null,
    name       text        not null,
    score      integer     not null check (score >= 0),
    created_at timestamptz not null default now()
);

create index if not exists scores_game_score_idx
    on public.scores (game, score desc, created_at asc);

-- Anonymous players may insert and read, but never change or delete.
alter table public.scores enable row level security;

drop policy if exists "anyone can read scores"  on public.scores;
drop policy if exists "anyone can insert scores" on public.scores;

create policy "anyone can read scores"
    on public.scores for select
    to anon
    using (true);

create policy "anyone can insert scores"
    on public.scores for insert
    to anon
    with check (true);

-- (optional) cap abuse: reject absurd values at the database level
alter table public.scores add constraint scores_name_len
    check (char_length(name) between 1 and 24);
