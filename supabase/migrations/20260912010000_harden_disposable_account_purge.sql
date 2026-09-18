-- Forward-only hardening for disposable-account purges. Purge workflow audit rows
-- are retry state, not historical authorization activity; every other dependency
-- remains a retention gate before the external Auth delete.
alter table public.authorization_events drop constraint authorization_events_event_type_check;
alter table public.authorization_events add constraint authorization_events_event_type_check check (event_type in (
  'position_assigned', 'position_revoked', 'role_assigned', 'role_revoked',
  'account_created', 'account_deprovisioned', 'account_auth_ban_failed', 'account_auth_ban_completed',
  'website_content_editor_granted', 'website_content_editor_revoked',
  'account_reprovisioned', 'account_reprovision_reconciliation_needed',
  'disposable_test_data_classified', 'disposable_account_purge_started', 'disposable_account_purge_retry_started',
  'disposable_account_purge_auth_failed', 'disposable_account_purge_auth_verification_failed'
));

create or replace function public.begin_disposable_account_purge_from_server(target_user_id uuid, actor_user_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  is_retry boolean;
begin
  perform app_private.require_service_role();
  if target_user_id = actor_user_id or not app_private.is_active_proprietor(actor_user_id) then
    raise exception 'only a proprietor may purge another account' using errcode = '42501';
  end if;
  if exists (select 1 from public.admin_position_assignments where user_id = target_user_id and position_code = 'proprietor_super_admin') then
    raise exception 'proprietor records cannot be purged' using errcode = '42501';
  end if;
  if not exists (select 1 from public.profiles where id = target_user_id and is_disposable_test_data) then
    raise exception 'explicit disposable classification is required' using errcode = '42501';
  end if;

  -- Keep only the narrowly defined purge-saga events out of the history gate.
  -- Classification and prior retry outcomes are append-only evidence needed to
  -- resume a failed external delete; no other authorization history is erased.
  if exists (
    select 1 from public.authorization_events
    where (subject_user_id = target_user_id or actor_user_id = target_user_id)
      and event_type not in (
        'disposable_test_data_classified', 'disposable_account_purge_started',
        'disposable_account_purge_retry_started', 'disposable_account_purge_auth_failed',
        'disposable_account_purge_auth_verification_failed'
      )
  ) then
    raise exception 'purge refused: linked historical or person records require operator review' using errcode = '23514';
  end if;

  -- Fixed, schema-specific default-deny checks. These records retain authorship,
  -- provenance, or operational history and their profile FKs would otherwise
  -- cascade or null the actor identity when Auth deletes the profile.
  if exists (select 1 from public.students where profile_id = target_user_id)
     or exists (select 1 from public.teachers where profile_id = target_user_id)
     or exists (select 1 from public.guardians where profile_id = target_user_id)
     or exists (select 1 from public.timetable_entries where created_by = target_user_id)
     or exists (select 1 from public.attendance_sessions where created_by = target_user_id or updated_by = target_user_id)
     or exists (select 1 from public.attendance_records where recorded_by = target_user_id)
     or exists (select 1 from public.assignments where created_by = target_user_id)
     or exists (select 1 from public.assessments where created_by = target_user_id)
     or exists (select 1 from public.assessment_results where recorded_by = target_user_id)
     or exists (select 1 from public.announcements where created_by = target_user_id)
     or exists (select 1 from public.events where created_by = target_user_id)
     or exists (select 1 from public.documents where created_by = target_user_id)
     or exists (select 1 from public.operational_events where actor_user_id = target_user_id)
     or exists (select 1 from public.cms_pages where created_by = target_user_id or last_edited_by = target_user_id or published_by = target_user_id)
     or exists (select 1 from public.cms_news_posts where created_by = target_user_id or last_edited_by = target_user_id or published_by = target_user_id)
     or exists (select 1 from public.public_events where created_by = target_user_id or last_edited_by = target_user_id or published_by = target_user_id)
  then
    raise exception 'purge refused: linked historical or person records require operator review' using errcode = '23514';
  end if;

  select exists (
    select 1 from public.authorization_events
    where subject_user_id = target_user_id
      and event_type in ('disposable_account_purge_started', 'disposable_account_purge_retry_started', 'disposable_account_purge_auth_failed', 'disposable_account_purge_auth_verification_failed')
  ) into is_retry;

  delete from public.website_content_editor_assignments where user_id = target_user_id;
  update public.admin_position_assignments set revoked_at = now(), revoked_by = actor_user_id where user_id = target_user_id and revoked_at is null;
  delete from public.user_roles where user_id = target_user_id;
  update public.profiles set is_active = false, auth_ban_state = 'pending' where id = target_user_id;
  insert into public.authorization_events(actor_user_id, subject_user_id, event_type)
  values (actor_user_id, target_user_id, case when is_retry then 'disposable_account_purge_retry_started' else 'disposable_account_purge_started' end);
end;
$$;

create or replace function public.record_disposable_account_purge_auth_failed_from_server(target_user_id uuid, actor_user_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform app_private.require_service_role();
  if not app_private.is_active_proprietor(actor_user_id) then
    raise exception 'only a proprietor may record purge recovery state' using errcode = '42501';
  end if;
  if not exists (select 1 from public.profiles where id = target_user_id and is_disposable_test_data and not is_active) then
    raise exception 'target is not an eligible pending purge' using errcode = 'P0002';
  end if;
  insert into public.authorization_events(actor_user_id, subject_user_id, event_type)
  values (actor_user_id, target_user_id, 'disposable_account_purge_auth_failed');
end;
$$;

create function public.record_disposable_account_purge_auth_verification_failed_from_server(target_user_id uuid, actor_user_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform app_private.require_service_role();
  if not app_private.is_active_proprietor(actor_user_id) then
    raise exception 'only a proprietor may record purge recovery state' using errcode = '42501';
  end if;
  if not exists (select 1 from public.profiles where id = target_user_id and is_disposable_test_data and not is_active) then
    raise exception 'target is not an eligible pending purge' using errcode = 'P0002';
  end if;
  insert into public.authorization_events(actor_user_id, subject_user_id, event_type)
  values (actor_user_id, target_user_id, 'disposable_account_purge_auth_verification_failed');
end;
$$;

revoke all on function public.begin_disposable_account_purge_from_server(uuid, uuid), public.record_disposable_account_purge_auth_failed_from_server(uuid, uuid), public.record_disposable_account_purge_auth_verification_failed_from_server(uuid, uuid) from public, anon, authenticated;
grant execute on function public.begin_disposable_account_purge_from_server(uuid, uuid), public.record_disposable_account_purge_auth_failed_from_server(uuid, uuid), public.record_disposable_account_purge_auth_verification_failed_from_server(uuid, uuid) to service_role;
