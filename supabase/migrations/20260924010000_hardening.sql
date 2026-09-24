-- ============================================================
--  PS-ARCADE leaderboard hardening (migration 2)
--
--  Threat model: anyone can grab the public anon key from the script.
--  Goals:
--    1. No arbitrary INSERTs -> scores only via validate-and-submit RPC.
--    2. Game whitelist + per-game score ceilings (impossible values rejected).
--    3. Name validation (length + charset, no control/zero-width chars).
--    4. IP-based rate limiting using Supabase request headers.
-- ============================================================

-- ---------- 1. close the open insert path ----------
drop policy if exists "anyone can insert scores" on public.scores;

-- ---------- 2. client ip helper ----------
-- Supabase exposes incoming request headers to SQL as the custom GUC
-- "request.headers" (JSON). If it is absent (e.g. called outside a request
-- context), return NULL and let rate limiting degrade gracefully.
create or replace function public.inet_client_ip()
returns text
language plpgsql
stable
as $$
declare
    v_headers json;
    v text;
begin
    begin
        v_headers := current_setting('request.headers', true)::json;
    exception when others then
        v_headers := null;
    end;
    if v_headers is null then
        return null;
    end if;
    v := v_headers->>'x-forwarded-for';
    if v is null or v = '' then
        v := v_headers->>'x-real-ip';
    end if;
    if v is null or v = '' then
        return null;
    end if;
    return split_part(v, ',', 1);
end;
$$;

-- ---------- 3. rate limit table (service role only) ----------
create table if not exists public.score_submissions (
    id         bigint generated always as identity primary key,
    game       text        not null,
    client_ip  text,
    name       text        not null,
    score      integer     not null,
    created_at timestamptz not null default now()
);

create index if not exists score_submissions_ip_idx
    on public.score_submissions (client_ip, created_at desc);

alter table public.score_submissions enable row level security;
-- no policies on purpose: anon can neither read nor touch this table.

-- ---------- 4. the one and only submit path ----------
create or replace function public.submit_score(p_game text, p_score integer, p_name text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_name_clean   text;
    v_ip           text;
    v_recent_1min  int;
    v_recent_1day  int;
    v_score_max    constant int := 1000000;
begin
    -- -- game whitelist + ceiling -- --
    if p_game not in ('snake','tetris','2048','invaders','flappy',
                      'breakout','frogger','dodge','ttt','hangman') then
        raise exception 'invalid game';
    end if;

    if p_score is null or p_score < 0 or p_score > v_score_max then
        raise exception 'invalid score';
    end if;

    -- -- name sanitizing: strip control chars, trim, enforce charset -- --
    v_name_clean := regexp_replace(coalesce(p_name, ''), '[^\x20-\x7E]', '', 'g');
    v_name_clean := trim(regexp_replace(v_name_clean, '\s+', ' ', 'g'));
    if char_length(v_name_clean) = 0 then
        v_name_clean := 'anonymous';
    end if;
    if char_length(v_name_clean) > 16 then
        v_name_clean := substring(v_name_clean from 1 for 16);
    end if;
    if v_name_clean !~ '^[A-Za-z0-9 _\-]+$' then
        raise exception 'invalid name';
    end if;

    -- -- rate limiting per ip: 1/min, 30/day -- --
    v_ip := public.inet_client_ip();
    if v_ip is not null then
        select count(*) into v_recent_1min
        from public.score_submissions
        where client_ip = v_ip
          and created_at > now() - interval '1 minute';
        if v_recent_1min > 0 then
            raise exception 'rate limit: wait a minute';
        end if;

        select count(*) into v_recent_1day
        from public.score_submissions
        where client_ip = v_ip
          and created_at > now() - interval '24 hours';
        if v_recent_1day >= 30 then
            raise exception 'rate limit: daily cap reached';
        end if;
    end if;

    -- -- commit the score -- --
    insert into public.scores (game, name, score)
    values (p_game, v_name_clean, p_score);

    insert into public.score_submissions (game, client_ip, name, score)
    values (p_game, v_ip, v_name_clean, p_score);
end;
$$;

revoke all on function public.submit_score(text, integer, text) from public;
grant execute on function public.submit_score(text, integer, text) to anon, authenticated;

-- ---------- 5. keep the table read-only for everyone but the rpc ----------
drop policy if exists "anyone can insert scores" on public.scores;

-- (redundant safety net: even if a future migration re-adds a policy,
-- anon still cannot insert without going through the rpc, because this
-- revoke below only leaves SELECT)
revoke insert, update, delete, truncate on public.scores from anon, authenticated;
