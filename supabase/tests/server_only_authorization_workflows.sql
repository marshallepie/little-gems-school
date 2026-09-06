-- Server-only authorization workflow behavioural checks.
-- Run after account_lifecycle_and_profiles.sql on a disposable local stack.
begin;

-- Browser-authenticated JWTs cannot forge Auth-ban saga state, even for Tier 1.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'b1000000-0000-0000-0000-000000000001', true);
do $$ begin
  begin
    perform public.record_account_auth_ban_state_from_server('c1000000-0000-0000-0000-000000000004', 'b1000000-0000-0000-0000-000000000001', 'succeeded');
    raise exception 'authenticated browser JWT forged an Auth-ban event';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.set_admin_position_from_server('b1000000-0000-0000-0000-000000000002', 'b1000000-0000-0000-0000-000000000001', 'headmistress');
    raise exception 'authenticated browser JWT changed an administrator position';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

-- The trusted capability still validates the preserved original actor, rather than
-- treating possession of the service key as authority to attribute arbitrary work.
set local role service_role;
select set_config('request.jwt.claim.role', 'service_role', true);
do $$ begin
  begin
    perform public.set_admin_position_from_server('b1000000-0000-0000-0000-000000000002', 'b1000000-0000-0000-0000-000000000003', 'headmistress');
    raise exception 'non-proprietor actor was accepted by service capability';
  exception when insufficient_privilege then null;
  end;
end $$;

-- A proprietor-approved trusted backend can replace/revoke Tier 2/3 and retains
-- the original proprietor identity in trigger-generated audit events.
select public.set_admin_position_from_server('b1000000-0000-0000-0000-000000000002', 'b1000000-0000-0000-0000-000000000001', 'headmistress');
do $$ begin
  if not exists (select 1 from public.admin_position_assignments where user_id = 'b1000000-0000-0000-0000-000000000002' and position_code = 'headmistress' and revoked_at is null) then raise exception 'trusted position replacement failed'; end if;
  if not exists (select 1 from public.authorization_events where actor_user_id = 'b1000000-0000-0000-0000-000000000001' and subject_user_id = 'b1000000-0000-0000-0000-000000000002' and event_type = 'position_assigned' and position_code = 'headmistress') then raise exception 'position assignment audit actor was not retained'; end if;
  begin
    perform public.set_admin_position_from_server('b1000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'headmistress');
    raise exception 'proprietor changed their own position';
  exception when insufficient_privilege then null;
  end;
end $$;
select public.set_admin_position_from_server('b1000000-0000-0000-0000-000000000002', 'b1000000-0000-0000-0000-000000000001', null);
do $$ begin
  if exists (select 1 from public.admin_position_assignments where user_id = 'b1000000-0000-0000-0000-000000000002' and revoked_at is null) then raise exception 'trusted position revoke failed'; end if;
end $$;
reset role;

rollback;
\echo 'PASS: server-only authorization workflow behavioural tests'
