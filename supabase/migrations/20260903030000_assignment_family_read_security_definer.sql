-- Repair family assignment reads without exposing teacher assignments to families.
create function app_private.can_read_assignment(target_assignment_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.assignments a
    join public.teacher_assignments ta on ta.id = a.teacher_assignment_id
    join public.class_enrolments ce on ce.class_group_id = ta.class_group_id
    where a.id = target_assignment_id
      and a.status = 'published'
      and ce.status = 'active'
      and ce.starts_on <= current_date
      and (ce.ends_on is null or ce.ends_on >= current_date)
      and (
        app_private.is_active_student_self(ce.student_id)
        or app_private.is_active_guardian_of(ce.student_id)
      )
  );
$$;

revoke all on function app_private.can_read_assignment(uuid)
  from public, anon, authenticated;
grant execute on function app_private.can_read_assignment(uuid) to authenticated;

drop policy assignments_family_read on public.assignments;
create policy assignments_family_read on public.assignments
  for select to authenticated
  using (app_private.can_read_assignment(id));
