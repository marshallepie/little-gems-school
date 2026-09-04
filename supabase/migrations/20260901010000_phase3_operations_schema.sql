-- Phase 3 operational records. Sensitive content stays in first-class columns;
-- JSON metadata is transport/audit metadata only, never relational data.
create extension if not exists btree_gist;

create table public.timetable_entries (
 id uuid primary key default gen_random_uuid(), term_id uuid not null references public.terms(id) on delete restrict,
 class_group_id uuid not null references public.class_groups(id) on delete restrict,
 subject_id uuid not null references public.subjects(id) on delete restrict,
 teacher_assignment_id uuid references public.teacher_assignments(id) on delete restrict,
 weekday smallint not null check (weekday between 1 and 7), session_number smallint not null check (session_number > 0),
 starts_at time not null, ends_at time not null, created_by uuid references public.profiles(id) on delete set null,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), check (ends_at > starts_at)
);
alter table public.timetable_entries add constraint timetable_entries_no_class_overlap exclude using gist (term_id with =, class_group_id with =, weekday with =, tsrange(('2000-01-01'::date + starts_at)::timestamp, ('2000-01-01'::date + ends_at)::timestamp, '[)') with &&);

create table public.attendance_sessions (
 id uuid primary key default gen_random_uuid(), class_group_id uuid not null references public.class_groups(id) on delete restrict,
 attendance_date date not null, session_number smallint not null default 1 check (session_number > 0),
 timetable_entry_id uuid references public.timetable_entries(id) on delete set null,
 status text not null default 'draft' check (status in ('draft','submitted','corrected')),
 student_visible boolean not null default false, submitted_at timestamptz,
 created_by uuid references public.profiles(id) on delete set null, updated_by uuid references public.profiles(id) on delete set null,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique (class_group_id, attendance_date, session_number), check ((status = 'draft' and submitted_at is null) or (status in ('submitted','corrected') and submitted_at is not null)), check (not student_visible or status in ('submitted','corrected'))
);
create table public.attendance_records (
 id uuid primary key default gen_random_uuid(), attendance_session_id uuid not null references public.attendance_sessions(id) on delete cascade,
 student_id uuid not null references public.students(id) on delete restrict,
 status text not null check (status in ('present','absent','late','excused')),
 recorded_at timestamptz not null default now(), recorded_by uuid references public.profiles(id) on delete set null,
 unique(attendance_session_id, student_id)
);

create table public.assignments (
 id uuid primary key default gen_random_uuid(), teacher_assignment_id uuid not null references public.teacher_assignments(id) on delete restrict,
 term_id uuid not null references public.terms(id) on delete restrict, title text not null check (length(btrim(title)) between 1 and 200), instructions text not null default '',
 assigned_on date not null, due_on date, status text not null default 'draft' check (status in ('draft','published','closed')),
 published_at timestamptz, created_by uuid references public.profiles(id) on delete set null, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 check (due_on is null or due_on >= assigned_on), check ((status = 'draft' and published_at is null) or (status in ('published','closed') and published_at is not null))
);
create table public.assessments (
 id uuid primary key default gen_random_uuid(), teacher_assignment_id uuid not null references public.teacher_assignments(id) on delete restrict,
 term_id uuid not null references public.terms(id) on delete restrict, assignment_id uuid references public.assignments(id) on delete set null,
 title text not null check (length(btrim(title)) between 1 and 200), assessment_date date not null, maximum_score numeric(8,2) not null check (maximum_score > 0),
 status text not null default 'draft' check (status in ('draft','published','released')), published_at timestamptz, released_at timestamptz,
 created_by uuid references public.profiles(id) on delete set null, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 check ((status = 'draft' and published_at is null and released_at is null) or (status = 'published' and published_at is not null and released_at is null) or (status = 'released' and published_at is not null and released_at is not null))
);
create table public.assessment_results (
 id uuid primary key default gen_random_uuid(), assessment_id uuid not null references public.assessments(id) on delete cascade,
 student_id uuid not null references public.students(id) on delete restrict, score numeric(8,2) not null check (score >= 0),
 feedback text not null default '', recorded_by uuid references public.profiles(id) on delete set null, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(assessment_id, student_id)
);

create table public.announcements (
 id uuid primary key default gen_random_uuid(), title text not null check (length(btrim(title)) between 1 and 200), body text not null,
 status text not null default 'draft' check (status in ('draft','published','archived')), published_at timestamptz,
 created_by uuid references public.profiles(id) on delete set null, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), check ((status = 'draft' and published_at is null) or (status in ('published','archived') and published_at is not null))
);
create table public.announcement_targets (announcement_id uuid not null references public.announcements(id) on delete cascade, target_kind text not null check (target_kind in ('school','role','class')), role_code text references public.roles(code) on delete restrict, class_group_id uuid references public.class_groups(id) on delete restrict, primary key(announcement_id,target_kind,role_code,class_group_id), check ((target_kind='school' and role_code is null and class_group_id is null) or (target_kind='role' and role_code is not null and class_group_id is null) or (target_kind='class' and role_code is null and class_group_id is not null)));
create table public.events (
 id uuid primary key default gen_random_uuid(), title text not null check (length(btrim(title)) between 1 and 200), description text not null default '', starts_at timestamptz not null, ends_at timestamptz not null,
 is_public boolean not null default false check (is_public = false), status text not null default 'draft' check (status in ('draft','published','cancelled')), published_at timestamptz,
 created_by uuid references public.profiles(id) on delete set null, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), check(ends_at > starts_at), check ((status='draft' and published_at is null) or (status in ('published','cancelled') and published_at is not null))
);
create table public.event_targets (event_id uuid not null references public.events(id) on delete cascade, target_kind text not null check (target_kind in ('school','role','class')), role_code text references public.roles(code) on delete restrict, class_group_id uuid references public.class_groups(id) on delete restrict, primary key(event_id,target_kind,role_code,class_group_id), check ((target_kind='school' and role_code is null and class_group_id is null) or (target_kind='role' and role_code is not null and class_group_id is null) or (target_kind='class' and role_code is null and class_group_id is not null)));

create table public.documents (
 id uuid primary key default gen_random_uuid(), title text not null check (length(btrim(title)) between 1 and 200), file_name text not null check (length(btrim(file_name)) > 0), mime_type text not null check (mime_type in ('application/pdf','application/vnd.openxmlformats-officedocument.wordprocessingml.document','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','image/png','image/jpeg')),
 byte_size bigint not null check (byte_size > 0 and byte_size <= 10485760), storage_path text generated always as ('documents/' || id::text) stored unique, status text not null default 'draft' check (status in ('draft','available','archived')), available_at timestamptz,
 created_by uuid references public.profiles(id) on delete set null, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), check ((status='draft' and available_at is null) or (status in ('available','archived') and available_at is not null))
);
create table public.document_targets (document_id uuid not null references public.documents(id) on delete cascade, target_kind text not null check (target_kind in ('school','role','class')), role_code text references public.roles(code) on delete restrict, class_group_id uuid references public.class_groups(id) on delete restrict, primary key(document_id,target_kind,role_code,class_group_id), check ((target_kind='school' and role_code is null and class_group_id is null) or (target_kind='role' and role_code is not null and class_group_id is null) or (target_kind='class' and role_code is null and class_group_id is not null)));
create table public.assignment_documents (assignment_id uuid not null references public.assignments(id) on delete cascade, document_id uuid not null references public.documents(id) on delete restrict, primary key(assignment_id,document_id));

create function app_private.can_access_document(target_document_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.documents d where d.id = target_document_id and (
      app_private.has_admin_permission('documents.manage')
      or (d.created_by = (select auth.uid()))
      or (d.status = 'available' and exists (select 1 from public.document_targets dt where dt.document_id = d.id and app_private.matches_audience(dt.target_kind, dt.role_code, dt.class_group_id)))
    )
  );
$$;
revoke all on function app_private.can_access_document(uuid) from public, anon;
grant execute on function app_private.can_access_document(uuid) to authenticated;

create table public.operational_events (id uuid primary key default gen_random_uuid(), occurred_at timestamptz not null default now(), actor_user_id uuid references public.profiles(id) on delete set null, entity_type text not null check(entity_type in ('attendance_session','assessment','document','announcement','event')), entity_id uuid not null, event_type text not null, metadata jsonb not null default '{}'::jsonb check(jsonb_typeof(metadata)='object'));

create function app_private.validate_phase3_record() returns trigger language plpgsql security definer set search_path = '' as $$
declare a public.teacher_assignments%rowtype; d date; max_score numeric;
begin
 if tg_table_name = 'timetable_entries' then
   if not exists(select 1 from public.terms t join public.class_groups c on c.academic_year_id=t.academic_year_id where t.id=new.term_id and c.id=new.class_group_id) then raise exception 'timetable class must belong to term academic year' using errcode='23514'; end if;
   if new.teacher_assignment_id is not null and not exists(select 1 from public.teacher_assignments ta where ta.id=new.teacher_assignment_id and ta.class_group_id=new.class_group_id and ta.subject_id=new.subject_id and (ta.term_id is null or ta.term_id=new.term_id)) then raise exception 'timetable assignment mismatch' using errcode='23514'; end if;
 elsif tg_table_name = 'attendance_sessions' then
   if new.timetable_entry_id is not null and not exists(select 1 from public.timetable_entries te where te.id=new.timetable_entry_id and te.class_group_id=new.class_group_id and extract(isodow from new.attendance_date)=te.weekday and te.session_number=new.session_number) then raise exception 'attendance timetable mismatch' using errcode='23514'; end if;
 elsif tg_table_name = 'attendance_records' then
   select attendance_date into d from public.attendance_sessions where id=new.attendance_session_id;
   if not app_private.is_enrolled_on(new.student_id,(select class_group_id from public.attendance_sessions where id=new.attendance_session_id),d) then raise exception 'attendance student is not eligible for session roster' using errcode='23514'; end if;
 elsif tg_table_name in ('assignments','assessments') then
   select * into a from public.teacher_assignments where id=new.teacher_assignment_id;
   if a.term_id is not null and a.term_id <> new.term_id then raise exception 'assignment term does not match teacher assignment' using errcode='23514'; end if;
   if not exists(select 1 from public.terms t join public.class_groups c on c.academic_year_id=t.academic_year_id where t.id=new.term_id and c.id=a.class_group_id) then raise exception 'operational term/class mismatch' using errcode='23514'; end if;
   if tg_table_name='assignments' and not exists(select 1 from public.terms where id=new.term_id and new.assigned_on between starts_on and ends_on) then raise exception 'assignment date outside term' using errcode='23514'; end if;
   if tg_table_name='assessments' then
     if not exists(select 1 from public.terms where id=new.term_id and new.assessment_date between starts_on and ends_on) then raise exception 'assessment date outside term' using errcode='23514'; end if;
     if new.assignment_id is not null and not exists(select 1 from public.assignments x where x.id=new.assignment_id and x.teacher_assignment_id=new.teacher_assignment_id and x.term_id=new.term_id) then raise exception 'assessment assignment mismatch' using errcode='23514'; end if;
   end if;
 elsif tg_table_name='assessment_results' then
   select maximum_score into max_score from public.assessments where id=new.assessment_id;
   if new.score > max_score then raise exception 'score exceeds assessment maximum' using errcode='23514'; end if;
   if not app_private.is_enrolled_on(new.student_id,(select ta.class_group_id from public.assessments x join public.teacher_assignments ta on ta.id=x.teacher_assignment_id where x.id=new.assessment_id),(select assessment_date from public.assessments where id=new.assessment_id)) then raise exception 'result student not enrolled for assessment' using errcode='23514'; end if;
 elsif tg_table_name='documents' then
   if new.storage_path <> 'documents/' || new.id::text then raise exception 'document path must be deterministic' using errcode='23514'; end if;
 end if; return new;
end; $$;
create function app_private.phase3_updated_at() returns trigger language plpgsql security definer set search_path = '' as $$ begin new.updated_at=now(); return new; end; $$;
create function app_private.audit_phase3_transition() returns trigger language plpgsql security definer set search_path = '' as $$ begin if tg_op='UPDATE' and ((tg_table_name='attendance_sessions' and old.status is distinct from new.status) or (tg_table_name='assessments' and old.status is distinct from new.status) or (tg_table_name='documents' and old.status is distinct from new.status)) then insert into public.operational_events(actor_user_id,entity_type,entity_id,event_type,metadata) values ((select auth.uid()),replace(tg_table_name,'_sessions','_session'),new.id,'status_changed',jsonb_build_object('from',old.status,'to',new.status)); end if; return new; end; $$;
create function app_private.prevent_operational_event_mutation() returns trigger language plpgsql security definer set search_path = '' as $$ begin raise exception 'operational events are append-only' using errcode='55000'; end; $$;

create trigger timetable_entries_validate before insert or update on public.timetable_entries for each row execute procedure app_private.validate_phase3_record();
create trigger attendance_sessions_validate before insert or update on public.attendance_sessions for each row execute procedure app_private.validate_phase3_record();
create trigger attendance_records_validate before insert or update on public.attendance_records for each row execute procedure app_private.validate_phase3_record();
create trigger assignments_validate before insert or update on public.assignments for each row execute procedure app_private.validate_phase3_record();
create trigger assessments_validate before insert or update on public.assessments for each row execute procedure app_private.validate_phase3_record();
create trigger assessment_results_validate before insert or update on public.assessment_results for each row execute procedure app_private.validate_phase3_record();
create trigger documents_validate before insert or update on public.documents for each row execute procedure app_private.validate_phase3_record();
create trigger attendance_sessions_audit after update on public.attendance_sessions for each row execute procedure app_private.audit_phase3_transition();
create trigger assessments_audit after update on public.assessments for each row execute procedure app_private.audit_phase3_transition();
create trigger documents_audit after update on public.documents for each row execute procedure app_private.audit_phase3_transition();
create trigger operational_events_append_only before update or delete on public.operational_events for each row execute procedure app_private.prevent_operational_event_mutation();
create trigger timetable_entries_updated before update on public.timetable_entries for each row execute procedure app_private.phase3_updated_at();
create trigger attendance_sessions_updated before update on public.attendance_sessions for each row execute procedure app_private.phase3_updated_at();
create trigger assignments_updated before update on public.assignments for each row execute procedure app_private.phase3_updated_at();
create trigger assessments_updated before update on public.assessments for each row execute procedure app_private.phase3_updated_at();
create trigger assessment_results_updated before update on public.assessment_results for each row execute procedure app_private.phase3_updated_at();
create trigger announcements_updated before update on public.announcements for each row execute procedure app_private.phase3_updated_at();
create trigger events_updated before update on public.events for each row execute procedure app_private.phase3_updated_at();
create trigger documents_updated before update on public.documents for each row execute procedure app_private.phase3_updated_at();

create index attendance_records_student_idx on public.attendance_records(student_id); create index assignments_teacher_assignment_idx on public.assignments(teacher_assignment_id,status); create index assessments_teacher_assignment_idx on public.assessments(teacher_assignment_id,status); create index assessment_results_student_idx on public.assessment_results(student_id); create index announcement_targets_class_idx on public.announcement_targets(class_group_id); create index event_targets_class_idx on public.event_targets(class_group_id); create index document_targets_class_idx on public.document_targets(class_group_id);
