-- Phase 3 assignment workflow repair. A teacher's authority is tied to the exact
-- persisted teacher_assignment_id, never a class/subject/term tuple that another
-- concurrent teacher could also hold.
create function app_private.is_active_teacher_for_teacher_assignment(target_teacher_assignment_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.teachers t
    join public.teacher_assignments ta on ta.teacher_id = t.id
    join public.profiles p on p.id = t.profile_id and p.is_active
    where t.profile_id = (select auth.uid())
      and t.employment_status = 'active'
      and ta.id = target_teacher_assignment_id
  );
$$;
revoke all on function app_private.is_active_teacher_for_teacher_assignment(uuid) from public, anon;
grant execute on function app_private.is_active_teacher_for_teacher_assignment(uuid) to authenticated;

-- Replace the permissive tuple-based policies; policy predicates OR-combine, so
-- keeping the old policies would retain the cross-teacher draft access path.
drop policy if exists assignments_teacher_all on public.assignments;
drop policy if exists assessments_teacher_draft on public.assessments;
drop policy if exists assessment_results_teacher_draft on public.assessment_results;
drop policy if exists assignment_documents_teacher_draft on public.assignment_documents;

-- Teachers may read, create, and edit only drafts owned by their exact persisted
-- teaching assignment. There is deliberately no teacher delete or transition
-- policy: assignment publication/closure is an assessments.review workflow.
create policy assignments_teacher_draft_select on public.assignments for select to authenticated
  using (status = 'draft' and app_private.is_active_teacher_for_teacher_assignment(teacher_assignment_id));
create policy assignments_teacher_draft_insert on public.assignments for insert to authenticated
  with check (status = 'draft' and app_private.is_active_teacher_for_teacher_assignment(teacher_assignment_id));
create policy assignments_teacher_draft_update on public.assignments for update to authenticated
  using (status = 'draft' and app_private.is_active_teacher_for_teacher_assignment(teacher_assignment_id))
  with check (status = 'draft' and app_private.is_active_teacher_for_teacher_assignment(teacher_assignment_id));

create policy assessments_teacher_draft_select on public.assessments for select to authenticated
  using (status = 'draft' and app_private.is_active_teacher_for_teacher_assignment(teacher_assignment_id));
create policy assessments_teacher_draft_insert on public.assessments for insert to authenticated
  with check (status = 'draft' and app_private.is_active_teacher_for_teacher_assignment(teacher_assignment_id));
create policy assessments_teacher_draft_update on public.assessments for update to authenticated
  using (status = 'draft' and app_private.is_active_teacher_for_teacher_assignment(teacher_assignment_id))
  with check (status = 'draft' and app_private.is_active_teacher_for_teacher_assignment(teacher_assignment_id));

create policy assessment_results_teacher_draft_select on public.assessment_results for select to authenticated
  using (exists (select 1 from public.assessments a where a.id = assessment_id and a.status = 'draft' and app_private.is_active_teacher_for_teacher_assignment(a.teacher_assignment_id)));
create policy assessment_results_teacher_draft_insert on public.assessment_results for insert to authenticated
  with check (exists (select 1 from public.assessments a where a.id = assessment_id and a.status = 'draft' and app_private.is_active_teacher_for_teacher_assignment(a.teacher_assignment_id)));
create policy assessment_results_teacher_draft_update on public.assessment_results for update to authenticated
  using (exists (select 1 from public.assessments a where a.id = assessment_id and a.status = 'draft' and app_private.is_active_teacher_for_teacher_assignment(a.teacher_assignment_id)))
  with check (exists (select 1 from public.assessments a where a.id = assessment_id and a.status = 'draft' and app_private.is_active_teacher_for_teacher_assignment(a.teacher_assignment_id)));

create policy assignment_documents_teacher_draft_select on public.assignment_documents for select to authenticated
  using (exists (select 1 from public.assignments a where a.id = assignment_id and a.status = 'draft' and app_private.is_active_teacher_for_teacher_assignment(a.teacher_assignment_id)));
create policy assignment_documents_teacher_draft_insert on public.assignment_documents for insert to authenticated
  with check (exists (select 1 from public.assignments a where a.id = assignment_id and a.status = 'draft' and app_private.is_active_teacher_for_teacher_assignment(a.teacher_assignment_id)));
create policy assignment_documents_teacher_draft_update on public.assignment_documents for update to authenticated
  using (exists (select 1 from public.assignments a where a.id = assignment_id and a.status = 'draft' and app_private.is_active_teacher_for_teacher_assignment(a.teacher_assignment_id)))
  with check (exists (select 1 from public.assignments a where a.id = assignment_id and a.status = 'draft' and app_private.is_active_teacher_for_teacher_assignment(a.teacher_assignment_id)));
create policy assignment_documents_teacher_draft_delete on public.assignment_documents for delete to authenticated
  using (exists (select 1 from public.assignments a where a.id = assignment_id and a.status = 'draft' and app_private.is_active_teacher_for_teacher_assignment(a.teacher_assignment_id)));
