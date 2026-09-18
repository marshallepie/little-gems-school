-- Forward-only account-management hierarchy, explicit disposable-data classification,
-- and a service-only purge preflight. Existing deprovisioning remains the default.
alter table public.profiles
  add column is_disposable_test_data boolean not null default false,
  add column disposable_classified_at timestamptz,
  add column disposable_classified_by uuid references public.profiles(id) on delete set null,
  add constraint profiles_disposable_classification check (
    (not is_disposable_test_data and disposable_classified_at is null and disposable_classified_by is null)
    or (is_disposable_test_data and disposable_classified_at is not null and disposable_classified_by is not null)
  );

alter table public.authorization_events drop constraint authorization_events_event_type_check;
alter table public.authorization_events add constraint authorization_events_event_type_check check (event_type in (
  'position_assigned', 'position_revoked', 'role_assigned', 'role_revoked',
  'account_created', 'account_deprovisioned', 'account_auth_ban_failed', 'account_auth_ban_completed',
  'website_content_editor_granted', 'website_content_editor_revoked',
  'account_reprovisioned', 'account_reprovision_reconciliation_needed',
  'disposable_test_data_classified', 'disposable_account_purge_started', 'disposable_account_purge_auth_failed'
));

-- This boolean capability is the only browser-visible hierarchy fact. It is derived
-- from the cookie-bound identity, not from FormData or caller supplied metadata.
create function public.account_management_capabilities()
returns jsonb language sql stable security definer set search_path = '' as $$
  select case
    when app_private.has_admin_position('proprietor_super_admin') then
      jsonb_build_object('manage_accounts', true, 'can_purge_disposable', true, 'position', 'proprietor_super_admin')
    when app_private.has_admin_position('senior_administrator') then
      jsonb_build_object('manage_accounts', true, 'can_purge_disposable', false, 'position', 'senior_administrator')
    when app_private.has_admin_position('headmistress') then
      jsonb_build_object('manage_accounts', true, 'can_purge_disposable', false, 'position', 'headmistress')
    else jsonb_build_object('manage_accounts', false, 'can_purge_disposable', false, 'position', null)
  end;
$$;

create function app_private.can_manage_account_target(actor_user_id uuid, target_role_code text, target_position_code text)
returns boolean language sql stable security definer set search_path = '' as $$
  select case
    when app_private.is_active_proprietor(actor_user_id) then
      target_role_code in ('teacher', 'parent', 'student', 'secretary')
      or (target_role_code = 'admin' and target_position_code in ('senior_administrator', 'headmistress'))
    when exists (select 1 from public.admin_position_assignments a join public.profiles p on p.id=a.user_id and p.is_active
      where a.user_id=actor_user_id and a.position_code='senior_administrator' and a.revoked_at is null) then
      target_role_code in ('teacher', 'parent', 'student', 'secretary')
      or (target_role_code = 'admin' and target_position_code = 'headmistress')
    when exists (select 1 from public.admin_position_assignments a join public.profiles p on p.id=a.user_id and p.is_active
      where a.user_id=actor_user_id and a.position_code='headmistress' and a.revoked_at is null) then
      target_role_code in ('teacher', 'parent', 'student', 'secretary')
    else false end;
$$;

create function public.provision_portal_account_from_server(target_user_id uuid, actor_user_id uuid, target_role_code text, target_position_code text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare selected_role_id uuid;
begin
  perform app_private.require_service_role();
  if target_user_id = actor_user_id then raise exception 'an actor cannot provision their own account' using errcode='42501'; end if;
  if (target_role_code='admin') <> (target_position_code is not null) then raise exception 'administrator accounts require exactly one position' using errcode='23514'; end if;
  if not app_private.can_manage_account_target(actor_user_id, target_role_code, target_position_code) then raise exception 'actor cannot create that account type' using errcode='42501'; end if;
  if not exists (select 1 from auth.users where id=target_user_id) then raise exception 'target must be an Auth identity' using errcode='23503'; end if;
  if not exists (select 1 from public.profiles where id=target_user_id and default_role_code is null and is_active and not is_disposable_test_data)
     or exists (select 1 from public.user_roles where user_id=target_user_id) then raise exception 'target is already provisioned, inactive, or classified disposable' using errcode='23505'; end if;
  select id into selected_role_id from public.roles where code=target_role_code;
  if selected_role_id is null then raise exception 'selected portal role is unavailable' using errcode='23503'; end if;
  update public.profiles set default_role_code=target_role_code where id=target_user_id;
  insert into public.user_roles(user_id, role_id) values(target_user_id, selected_role_id);
  if target_position_code is not null then insert into public.admin_position_assignments(user_id, position_code, assigned_by) values(target_user_id,target_position_code,actor_user_id); end if;
  insert into public.authorization_events(actor_user_id,subject_user_id,event_type,role_code,position_code) values(actor_user_id,target_user_id,'account_created',target_role_code,target_position_code);
end;
$$;

-- Classification is intentionally service-only and is only available to the active
-- proprietor; names, domains, and user metadata never imply disposable status.
create function public.classify_disposable_test_account_from_server(target_user_id uuid, actor_user_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform app_private.require_service_role();
  if actor_user_id=target_user_id or not app_private.is_active_proprietor(actor_user_id) then raise exception 'only a proprietor may classify another account' using errcode='42501'; end if;
  if exists (select 1 from public.admin_position_assignments where user_id=target_user_id and position_code='proprietor_super_admin') then raise exception 'proprietor records cannot be classified disposable' using errcode='42501'; end if;
  update public.profiles set is_disposable_test_data=true, disposable_classified_at=now(), disposable_classified_by=actor_user_id where id=target_user_id and is_active;
  if not found then raise exception 'target is not an active account' using errcode='P0002'; end if;
  insert into public.authorization_events(actor_user_id,subject_user_id,event_type) values(actor_user_id,target_user_id,'disposable_test_data_classified');
end;
$$;

-- Reject every known historical/person dependency before the external Auth delete.
-- This deliberately errs on retention: unsupported references must be removed by an
-- operator from disposable fixtures, never cascaded from a real account.
create function public.begin_disposable_account_purge_from_server(target_user_id uuid, actor_user_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform app_private.require_service_role();
  if target_user_id=actor_user_id or not app_private.is_active_proprietor(actor_user_id) then raise exception 'only a proprietor may purge another account' using errcode='42501'; end if;
  if exists(select 1 from public.admin_position_assignments where user_id=target_user_id and position_code='proprietor_super_admin') then raise exception 'proprietor records cannot be purged' using errcode='42501'; end if;
  if not exists(select 1 from public.profiles where id=target_user_id and is_disposable_test_data) then raise exception 'explicit disposable classification is required' using errcode='42501'; end if;
  if exists(select 1 from public.students where profile_id=target_user_id)
     or exists(select 1 from public.teachers where profile_id=target_user_id)
     or exists(select 1 from public.guardians where profile_id=target_user_id)
     or exists(select 1 from public.authorization_events where subject_user_id=target_user_id or actor_user_id=target_user_id) then
    raise exception 'purge refused: linked historical or person records require operator review' using errcode='23514';
  end if;
  delete from public.website_content_editor_assignments where user_id=target_user_id;
  update public.admin_position_assignments set revoked_at=now(), revoked_by=actor_user_id where user_id=target_user_id and revoked_at is null;
  delete from public.user_roles where user_id=target_user_id;
  update public.profiles set is_active=false, auth_ban_state='pending' where id=target_user_id;
  insert into public.authorization_events(actor_user_id,subject_user_id,event_type) values(actor_user_id,target_user_id,'disposable_account_purge_started');
end;
$$;

create function public.record_disposable_account_purge_auth_failed_from_server(target_user_id uuid, actor_user_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform app_private.require_service_role();
  if not app_private.is_active_proprietor(actor_user_id) then raise exception 'only a proprietor may record purge recovery state' using errcode='42501'; end if;
  if not exists(select 1 from public.profiles where id=target_user_id and is_disposable_test_data and not is_active) then raise exception 'target is not an eligible pending purge' using errcode='P0002'; end if;
  insert into public.authorization_events(actor_user_id,subject_user_id,event_type) values(actor_user_id,target_user_id,'disposable_account_purge_auth_failed');
end;
$$;

revoke all on function public.account_management_capabilities() from public, anon;
grant execute on function public.account_management_capabilities() to authenticated;
revoke all on function app_private.can_manage_account_target(uuid,text,text) from public,anon,authenticated,service_role;
revoke all on function public.provision_portal_account_from_server(uuid,uuid,text,text), public.classify_disposable_test_account_from_server(uuid,uuid), public.begin_disposable_account_purge_from_server(uuid,uuid), public.record_disposable_account_purge_auth_failed_from_server(uuid,uuid) from public,anon,authenticated;
grant execute on function public.provision_portal_account_from_server(uuid,uuid,text,text), public.classify_disposable_test_account_from_server(uuid,uuid), public.begin_disposable_account_purge_from_server(uuid,uuid), public.record_disposable_account_purge_auth_failed_from_server(uuid,uuid) to service_role;
