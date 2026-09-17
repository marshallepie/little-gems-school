-- Append-only command boundary for internal announcements and private calendar events.
-- Managers read their queue through RLS but mutate it only through these RPCs.

-- Broad Phase 3 admin policies allowed direct record and target writes. Replace them
-- with narrowly scoped management reads; SECURITY DEFINER commands below perform all
-- writes after checking the same active manager permission.
drop policy if exists announcements_admin on public.announcements;
drop policy if exists announcement_targets_admin on public.announcement_targets;
drop policy if exists events_admin on public.events;
drop policy if exists event_targets_admin on public.event_targets;
create policy announcements_manager_read on public.announcements for select to authenticated using (app_private.has_admin_permission('communications.manage'));
create policy announcement_targets_manager_read on public.announcement_targets for select to authenticated using (app_private.has_admin_permission('communications.manage'));
create policy events_manager_read on public.events for select to authenticated using (app_private.has_admin_permission('calendar.manage'));
create policy event_targets_manager_read on public.event_targets for select to authenticated using (app_private.has_admin_permission('calendar.manage'));

-- Audit reads are scoped to the permission for the audited entity, not to an
-- unrelated operational permission.
drop policy if exists operational_events_admin_read on public.operational_events;

-- The earlier transition-only trigger would duplicate the structured command audit.
drop trigger if exists announcements_audit_status_transition on public.announcements;
drop trigger if exists events_audit_status_transition on public.events;

create function app_private.validate_communications_targets(p_targets jsonb)
returns void language plpgsql security definer set search_path = '' as $$
declare
  target_count integer;
  distinct_count integer;
begin
  if p_targets is null or jsonb_typeof(p_targets) <> 'array' or jsonb_array_length(p_targets) = 0 then
    raise exception 'at least one audience is required' using errcode = '23514';
  end if;

  if exists (
    select 1 from jsonb_array_elements(p_targets) item
    where jsonb_typeof(item) <> 'object'
      or item - 'target_kind' - 'role_code' - 'class_group_id' <> '{}'::jsonb
  ) then
    raise exception 'audiences must have only target_kind, role_code, and class_group_id' using errcode = '23514';
  end if;

  with targets as (
    select target_kind, role_code, class_group_id
    from jsonb_to_recordset(p_targets) as t(target_kind text, role_code text, class_group_id text)
  )
  select count(*), count(distinct jsonb_build_array(target_kind, role_code, class_group_id))
  into target_count, distinct_count from targets;

  if target_count <> distinct_count then
    raise exception 'duplicate audiences are not allowed' using errcode = '23505';
  end if;

  if exists (
    select 1 from jsonb_to_recordset(p_targets) as t(target_kind text, role_code text, class_group_id text)
    where not (
      (target_kind = 'school' and role_code is null and class_group_id is null)
      or (target_kind = 'role' and role_code in ('admin', 'teacher', 'parent', 'student') and class_group_id is null)
      or (target_kind = 'class' and role_code is null and class_group_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
    )
  ) then
    raise exception 'invalid normalized audience' using errcode = '23514';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_targets) as t(target_kind text, role_code text, class_group_id text)
    where t.target_kind = 'class'
      and not app_private.is_current_class_group(t.class_group_id::uuid)
  ) then
    raise exception 'class audiences must use a current class group' using errcode = '23514';
  end if;
end;
$$;
revoke all on function app_private.validate_communications_targets(jsonb) from public, anon, authenticated;

create function app_private.enforce_announcement_lifecycle()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    if auth.uid() is null or new.created_by is distinct from auth.uid() then
      raise exception 'announcement creator must be the authenticated actor' using errcode = '42501';
    end if;
    if new.status <> 'draft' or new.published_at is not null then
      raise exception 'announcements must be created as drafts' using errcode = '23514';
    end if;
    return new;
  end if;

  if new.created_by is distinct from old.created_by then
    raise exception 'announcement creator is immutable' using errcode = '42501';
  end if;
  if old.status = 'draft' and new.status = 'draft' then
    if new.published_at is not null then raise exception 'draft announcements have no publication time' using errcode = '23514'; end if;
  elsif old.status = 'draft' and new.status = 'published' then
    if not exists (select 1 from public.announcement_targets where announcement_id = old.id) then
      raise exception 'published announcements require an audience' using errcode = '23514';
    end if;
    new.published_at := now();
  elsif old.status = 'published' and new.status = 'archived' then
    if new.title is distinct from old.title or new.body is distinct from old.body or new.published_at is distinct from old.published_at then
      raise exception 'published announcements can only be archived' using errcode = '23514';
    end if;
  else
    raise exception 'illegal announcement lifecycle transition from % to %', old.status, new.status using errcode = '23514';
  end if;
  return new;
end;
$$;
revoke all on function app_private.enforce_announcement_lifecycle() from public, anon, authenticated;
create trigger announcements_lifecycle_guard before insert or update on public.announcements for each row execute procedure app_private.enforce_announcement_lifecycle();

create function app_private.enforce_event_lifecycle()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    if auth.uid() is null or new.created_by is distinct from auth.uid() then
      raise exception 'event creator must be the authenticated actor' using errcode = '42501';
    end if;
    if new.status <> 'draft' or new.published_at is not null then
      raise exception 'events must be created as drafts' using errcode = '23514';
    end if;
    return new;
  end if;

  if new.created_by is distinct from old.created_by then
    raise exception 'event creator is immutable' using errcode = '42501';
  end if;
  if old.status = 'draft' and new.status = 'draft' then
    if new.published_at is not null then raise exception 'draft events have no publication time' using errcode = '23514'; end if;
  elsif old.status = 'draft' and new.status = 'published' then
    if not exists (select 1 from public.event_targets where event_id = old.id) then
      raise exception 'published events require an audience' using errcode = '23514';
    end if;
    new.published_at := now();
  elsif old.status = 'published' and new.status = 'cancelled' then
    if new.title is distinct from old.title or new.description is distinct from old.description
      or new.starts_at is distinct from old.starts_at or new.ends_at is distinct from old.ends_at
      or new.is_public is distinct from old.is_public or new.published_at is distinct from old.published_at then
      raise exception 'published events can only be cancelled' using errcode = '23514';
    end if;
  else
    raise exception 'illegal event lifecycle transition from % to %', old.status, new.status using errcode = '23514';
  end if;
  return new;
end;
$$;
revoke all on function app_private.enforce_event_lifecycle() from public, anon, authenticated;
create trigger events_lifecycle_guard before insert or update on public.events for each row execute procedure app_private.enforce_event_lifecycle();

create function public.manage_internal_announcement(
  p_id uuid, p_action text, p_title text, p_body text, p_targets jsonb
) returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_id uuid;
  v_old_status text;
  v_actor uuid := auth.uid();
begin
  if v_actor is null or not app_private.has_admin_permission('communications.manage') then
    raise exception 'communications manager permission is required' using errcode = '42501';
  end if;
  if p_action not in ('draft', 'publish', 'archive') or length(btrim(coalesce(p_title, ''))) not between 1 and 200 or length(btrim(coalesce(p_body, ''))) not between 1 and 10000 then
    raise exception 'invalid announcement command' using errcode = '23514';
  end if;

  if p_id is null then
    if p_action <> 'draft' then raise exception 'new announcements must be drafts' using errcode = '23514'; end if;
    perform app_private.validate_communications_targets(p_targets);
    insert into public.announcements(title, body, status, published_at, created_by)
    values (btrim(p_title), btrim(p_body), 'draft', null, v_actor) returning id into v_id;
    insert into public.announcement_targets(announcement_id, target_kind, role_code, class_group_id)
    select v_id, target_kind, role_code, class_group_id::uuid
    from jsonb_to_recordset(p_targets) as t(target_kind text, role_code text, class_group_id text);
    insert into public.operational_events(actor_user_id, entity_type, entity_id, event_type, metadata)
    values (v_actor, 'announcement', v_id, 'created', jsonb_build_object('status', 'draft')),
           (v_actor, 'announcement', v_id, 'audience_replaced', jsonb_build_object('target_count', jsonb_array_length(p_targets)));
    return v_id;
  end if;

  select status into v_old_status from public.announcements where id = p_id for update;
  if not found then raise exception 'announcement is unavailable' using errcode = 'P0002'; end if;
  v_id := p_id;
  if v_old_status = 'draft' and p_action in ('draft', 'publish') then
    perform app_private.validate_communications_targets(p_targets);
    update public.announcements set title = btrim(p_title), body = btrim(p_body) where id = v_id;
    delete from public.announcement_targets where announcement_id = v_id;
    insert into public.announcement_targets(announcement_id, target_kind, role_code, class_group_id)
    select v_id, target_kind, role_code, class_group_id::uuid
    from jsonb_to_recordset(p_targets) as t(target_kind text, role_code text, class_group_id text);
    insert into public.operational_events(actor_user_id, entity_type, entity_id, event_type, metadata)
    values (v_actor, 'announcement', v_id, 'content_changed', '{}'::jsonb),
           (v_actor, 'announcement', v_id, 'audience_replaced', jsonb_build_object('target_count', jsonb_array_length(p_targets)));
    if p_action = 'publish' then
      update public.announcements set status = 'published' where id = v_id;
      insert into public.operational_events(actor_user_id, entity_type, entity_id, event_type, metadata)
      values (v_actor, 'announcement', v_id, 'status_changed', jsonb_build_object('from', 'draft', 'to', 'published'));
    end if;
  elsif v_old_status = 'published' and p_action = 'archive' then
    update public.announcements set status = 'archived' where id = v_id;
    insert into public.operational_events(actor_user_id, entity_type, entity_id, event_type, metadata)
    values (v_actor, 'announcement', v_id, 'status_changed', jsonb_build_object('from', 'published', 'to', 'archived'));
  else
    raise exception 'illegal announcement command for %', v_old_status using errcode = '23514';
  end if;
  return v_id;
end;
$$;
revoke all on function public.manage_internal_announcement(uuid, text, text, text, jsonb) from public, anon;
grant execute on function public.manage_internal_announcement(uuid, text, text, text, jsonb) to authenticated;

create function public.manage_private_event(
  p_id uuid, p_action text, p_title text, p_description text, p_starts_at timestamptz, p_ends_at timestamptz, p_targets jsonb
) returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_id uuid;
  v_old_status text;
  v_actor uuid := auth.uid();
begin
  if v_actor is null or not app_private.has_admin_permission('calendar.manage') then
    raise exception 'calendar manager permission is required' using errcode = '42501';
  end if;
  if p_action not in ('draft', 'publish', 'cancel') or length(btrim(coalesce(p_title, ''))) not between 1 and 200
    or length(btrim(coalesce(p_description, ''))) > 10000 or p_starts_at is null or p_ends_at is null or p_ends_at <= p_starts_at then
    raise exception 'invalid event command' using errcode = '23514';
  end if;

  if p_id is null then
    if p_action <> 'draft' then raise exception 'new events must be drafts' using errcode = '23514'; end if;
    perform app_private.validate_communications_targets(p_targets);
    insert into public.events(title, description, starts_at, ends_at, is_public, status, published_at, created_by)
    values (btrim(p_title), btrim(p_description), p_starts_at, p_ends_at, false, 'draft', null, v_actor) returning id into v_id;
    insert into public.event_targets(event_id, target_kind, role_code, class_group_id)
    select v_id, target_kind, role_code, class_group_id::uuid
    from jsonb_to_recordset(p_targets) as t(target_kind text, role_code text, class_group_id text);
    insert into public.operational_events(actor_user_id, entity_type, entity_id, event_type, metadata)
    values (v_actor, 'event', v_id, 'created', jsonb_build_object('status', 'draft')),
           (v_actor, 'event', v_id, 'audience_replaced', jsonb_build_object('target_count', jsonb_array_length(p_targets)));
    return v_id;
  end if;

  select status into v_old_status from public.events where id = p_id for update;
  if not found then raise exception 'event is unavailable' using errcode = 'P0002'; end if;
  v_id := p_id;
  if v_old_status = 'draft' and p_action in ('draft', 'publish') then
    perform app_private.validate_communications_targets(p_targets);
    update public.events set title = btrim(p_title), description = btrim(p_description), starts_at = p_starts_at, ends_at = p_ends_at where id = v_id;
    delete from public.event_targets where event_id = v_id;
    insert into public.event_targets(event_id, target_kind, role_code, class_group_id)
    select v_id, target_kind, role_code, class_group_id::uuid
    from jsonb_to_recordset(p_targets) as t(target_kind text, role_code text, class_group_id text);
    insert into public.operational_events(actor_user_id, entity_type, entity_id, event_type, metadata)
    values (v_actor, 'event', v_id, 'content_changed', '{}'::jsonb),
           (v_actor, 'event', v_id, 'audience_replaced', jsonb_build_object('target_count', jsonb_array_length(p_targets)));
    if p_action = 'publish' then
      update public.events set status = 'published' where id = v_id;
      insert into public.operational_events(actor_user_id, entity_type, entity_id, event_type, metadata)
      values (v_actor, 'event', v_id, 'status_changed', jsonb_build_object('from', 'draft', 'to', 'published'));
    end if;
  elsif v_old_status = 'published' and p_action = 'cancel' then
    update public.events set status = 'cancelled' where id = v_id;
    insert into public.operational_events(actor_user_id, entity_type, entity_id, event_type, metadata)
    values (v_actor, 'event', v_id, 'status_changed', jsonb_build_object('from', 'published', 'to', 'cancelled'));
  else
    raise exception 'illegal event command for %', v_old_status using errcode = '23514';
  end if;
  return v_id;
end;
$$;
revoke all on function public.manage_private_event(uuid, text, text, text, timestamptz, timestamptz, jsonb) from public, anon;
grant execute on function public.manage_private_event(uuid, text, text, text, timestamptz, timestamptz, jsonb) to authenticated;
