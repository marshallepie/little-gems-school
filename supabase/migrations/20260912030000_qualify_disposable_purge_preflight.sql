-- Forward-only repair: qualify table columns in the service-only purge preflight
-- so PL/pgSQL parameters cannot collide with authorization_events column names.
create or replace function public.begin_disposable_account_purge_from_server(target_user_id uuid, actor_user_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  is_retry boolean;
begin
  perform app_private.require_service_role();
  if target_user_id = actor_user_id or not app_private.is_active_proprietor(actor_user_id) then
    raise exception 'only a proprietor may purge another account' using errcode = '42501';
  end if;
  if exists (
    select 1
    from public.admin_position_assignments as apa
    where apa.user_id = target_user_id
      and apa.position_code = 'proprietor_super_admin'
  ) then
    raise exception 'proprietor records cannot be purged' using errcode = '42501';
  end if;
  if not exists (
    select 1
    from public.profiles as p
    where p.id = target_user_id
      and p.is_disposable_test_data
  ) then
    raise exception 'explicit disposable classification is required' using errcode = '42501';
  end if;

  -- Keep only the narrowly defined purge-saga events out of the history gate.
  -- Classification and prior retry outcomes are append-only evidence needed to
  -- resume a failed external delete; no other authorization history is erased.
  if exists (
    select 1
    from public.authorization_events as ae
    where (ae.subject_user_id = target_user_id or ae.actor_user_id = target_user_id)
      and ae.event_type not in (
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
  if exists (select 1 from public.students as s where s.profile_id = target_user_id)
     or exists (select 1 from public.teachers as t where t.profile_id = target_user_id)
     or exists (select 1 from public.guardians as g where g.profile_id = target_user_id)
     or exists (select 1 from public.timetable_entries as te where te.created_by = target_user_id)
     or exists (select 1 from public.attendance_sessions as ats where ats.created_by = target_user_id or ats.updated_by = target_user_id)
     or exists (select 1 from public.attendance_records as atr where atr.recorded_by = target_user_id)
     or exists (select 1 from public.assignments as a where a.created_by = target_user_id)
     or exists (select 1 from public.assessments as ass where ass.created_by = target_user_id)
     or exists (select 1 from public.assessment_results as ar where ar.recorded_by = target_user_id)
     or exists (select 1 from public.announcements as an where an.created_by = target_user_id)
     or exists (select 1 from public.events as e where e.created_by = target_user_id)
     or exists (select 1 from public.documents as d where d.created_by = target_user_id)
     or exists (select 1 from public.operational_events as oe where oe.actor_user_id = target_user_id)
     or exists (select 1 from public.cms_pages as cp where cp.created_by = target_user_id or cp.last_edited_by = target_user_id or cp.published_by = target_user_id)
     or exists (select 1 from public.cms_news_posts as cnp where cnp.created_by = target_user_id or cnp.last_edited_by = target_user_id or cnp.published_by = target_user_id)
     or exists (select 1 from public.public_events as pe where pe.created_by = target_user_id or pe.last_edited_by = target_user_id or pe.published_by = target_user_id)
  then
    raise exception 'purge refused: linked historical or person records require operator review' using errcode = '23514';
  end if;

  select exists (
    select 1
    from public.authorization_events as ae
    where ae.subject_user_id = target_user_id
      and ae.event_type in (
        'disposable_account_purge_started', 'disposable_account_purge_retry_started',
        'disposable_account_purge_auth_failed', 'disposable_account_purge_auth_verification_failed'
      )
  ) into is_retry;

  delete from public.website_content_editor_assignments as wcea where wcea.user_id = target_user_id;
  update public.admin_position_assignments as apa
  set revoked_at = now(), revoked_by = actor_user_id
  where apa.user_id = target_user_id
    and apa.revoked_at is null;
  delete from public.user_roles as ur where ur.user_id = target_user_id;
  update public.profiles as p
  set is_active = false, auth_ban_state = 'pending'
  where p.id = target_user_id;
  insert into public.authorization_events(actor_user_id, subject_user_id, event_type)
  values (
    actor_user_id,
    target_user_id,
    case when is_retry then 'disposable_account_purge_retry_started' else 'disposable_account_purge_started' end
  );
end;
$$;

revoke all on function public.begin_disposable_account_purge_from_server(uuid, uuid) from public, anon, authenticated;
grant execute on function public.begin_disposable_account_purge_from_server(uuid, uuid) to service_role;
