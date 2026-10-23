-- Usporedba studenata po kolegiju (iz state.course). Pokreni jednom u SQL Editoru.
create or replace function public.stats_course()
returns table(course text, users integer, answered bigint, avg_level real, zad_n bigint, zad_pts real, kz_sims bigint, kz_best real, topics jsonb)
language sql security definer set search_path = public as $$
  with p as (
    select coalesce(nullif(state->>'course',''),'nepoznato') c, state from profiles
  )
  select c,
    count(*)::int,
    sum((select coalesce(sum((v->>'n')::int),0) from jsonb_each(coalesce(state->'ratings','{}'::jsonb)) r(k,v)))::bigint,
    avg((select avg((v->>'r')::real) from jsonb_each(coalesce(state->'ratings','{}'::jsonb)) r(k,v) where (v->>'n')::int > 0))::real,
    sum(coalesce((state->'zad'->>'n')::int,0))::bigint,
    avg(nullif(coalesce((state->'zad'->>'pts')::real,0),0))::real,
    sum(coalesce(jsonb_array_length(state->'kz'->'sims'),0))::bigint,
    avg((state->'kz'->>'best')::real)::real,
    (select coalesce(jsonb_object_agg(k, jsonb_build_object('lvl', lv, 'users', nu)),'{}'::jsonb) from (
       select r.k, avg((r.v->>'r')::real) lv, count(*) nu
       from p p2, jsonb_each(coalesce(p2.state->'ratings','{}'::jsonb)) r(k,v)
       where p2.c = p.c and (r.v->>'n')::int > 0 group by r.k) t)
  from p group by c order by 2 desc;
$$;
revoke all on function public.stats_course from public;
grant execute on function public.stats_course to anon, authenticated;
