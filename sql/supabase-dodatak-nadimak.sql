-- Dodatak: promjena nadimka i broj zadataka na javnom profilu. Pokreni jednom u SQL Editoru.

create or replace function public.rename_nick(p_token uuid, p_nick text)
returns void
language plpgsql security definer set search_path = public as $$
begin
  p_nick := btrim(p_nick);
  if char_length(p_nick) < 2 or char_length(p_nick) > 24 then raise exception 'bad_nick'; end if;
  if exists (select 1 from profiles p where lower(p.nick) = lower(p_nick) and p.token <> p_token) then raise exception 'nick_taken'; end if;
  update profiles set nick = p_nick, state = jsonb_set(state, '{nick}', to_jsonb(p_nick)), updated_at = now() where token = p_token;
  if not found then raise exception 'bad_token'; end if;
end $$;
revoke all on function public.rename_nick from public;
grant execute on function public.rename_nick to anon, authenticated;

create or replace function public.public_profile(p_nick text)
returns jsonb
language sql security definer set search_path = public as $$
  select jsonb_build_object(
    'nick', p.nick,
    'since', p.created_at,
    'name', case when p.show_name then p.full_name end,
    'state', jsonb_build_object(
      'ratings', coalesce(p.state->'ratings', '{}'::jsonb),
      'days',    coalesce(p.state->'days', '{}'::jsonb),
      'badges',  coalesce(p.state->'badges', '{}'::jsonb),
      'zad',     jsonb_build_object('full', coalesce(p.state->'zad'->'full', '{}'::jsonb),
                                    'n', coalesce(p.state->'zad'->'n', '0'::jsonb)),
      'week',    coalesce(p.state->'week', '{}'::jsonb)))
  from profiles p where lower(p.nick) = lower(btrim(p_nick));
$$;
