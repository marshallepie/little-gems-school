-- Append-only internal communications/calendar hardening. Applies only after
-- 20260901030000_phase3_operations_security_hardening.sql.
create function app_private.is_current_class_group(target_class_group_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.class_groups cg
    join public.academic_years ay on ay.id = cg.academic_year_id
    where cg.id = target_class_group_id and ay.is_current
  );
$$;
revoke all on function app_private.is_current_class_group(uuid) from public, anon;
grant execute on function app_private.is_current_class_group(uuid) to authenticated;

create function app_private.validate_current_communications_audience()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.target_kind = 'class' and not app_private.is_current_class_group(new.class_group_id) then
    raise exception 'class audiences must use a current class group' using errcode = '23514';
  end if;
  return new;
end;
$$;
revoke all on function app_private.validate_current_communications_audience() from public, anon, authenticated;
create trigger announcement_targets_current_class_validate before insert or update on public.announcement_targets for each row execute procedure app_private.validate_current_communications_audience();
create trigger event_targets_current_class_validate before insert or update on public.event_targets for each row execute procedure app_private.validate_current_communications_audience();

-- Communication/calendar managers can select only current class labels needed to
-- compose an audience; no broad people, relationship, or target enumeration grant.
create policy class_groups_communications_calendar_current_read on public.class_groups for select to authenticated using (
  app_private.is_current_class_group(id) and (app_private.has_admin_permission('communications.manage') or app_private.has_admin_permission('calendar.manage'))
);

create function app_private.audit_communications_calendar_transition()
returns trigger language plpgsql security definer set search_path = '' as $$
declare entity text;
begin
  if tg_op = 'UPDATE' and old.status is distinct from new.status then
    entity := case tg_table_name when 'announcements' then 'announcement' when 'events' then 'event' else null end;
    if entity is not null then
      insert into public.operational_events(actor_user_id, entity_type, entity_id, event_type, metadata)
      values ((select auth.uid()), entity, new.id, 'status_changed', jsonb_build_object('from', old.status, 'to', new.status));
    end if;
  end if;
  return new;
end;
$$;
revoke all on function app_private.audit_communications_calendar_transition() from public, anon, authenticated;
create trigger announcements_audit_status_transition after update of status on public.announcements for each row execute procedure app_private.audit_communications_calendar_transition();
create trigger events_audit_status_transition after update of status on public.events for each row execute procedure app_private.audit_communications_calendar_transition();

-- Audit readers are permission-bound, matching the entity they manage.
create policy operational_events_communications_calendar_admin_read on public.operational_events for select to authenticated using (
  (entity_type = 'announcement' and app_private.has_admin_permission('communications.manage'))
  or (entity_type = 'event' and app_private.has_admin_permission('calendar.manage'))
);
