-- ============================================================
--  PS-ARCADE: add 'pong' to the submit_score game whitelist
--  (full re-apply of the RPC from the hardening migration, idempotent)
-- ============================================================

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
                      'breakout','frogger','dodge','ttt','hangman','pong') then
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
