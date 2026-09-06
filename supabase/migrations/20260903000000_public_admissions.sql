-- Public admissions is deliberately separate from students, guardians, and Auth.
-- Applications and their documents are private by default; staff review never enrols a child.
create function app_private.new_admission_application_reference()
returns text language sql volatile set search_path = '' as $$
  select 'LG-' || to_char(current_date, 'YYYY') || '-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10));
$$;
revoke all on function app_private.new_admission_application_reference() from public, anon, authenticated;

create table public.admission_applications (
  id uuid primary key default gen_random_uuid(),
  application_reference text not null unique default app_private.new_admission_application_reference(),
  child_first_name text not null check (char_length(child_first_name) between 1 and 100),
  child_last_name text not null check (char_length(child_last_name) between 1 and 100),
  child_date_of_birth date not null check (child_date_of_birth <= current_date),
  requested_class text not null check (char_length(requested_class) between 1 and 100),
  guardian_first_name text not null check (char_length(guardian_first_name) between 1 and 100),
  guardian_last_name text not null check (char_length(guardian_last_name) between 1 and 100),
  guardian_relationship text not null check (char_length(guardian_relationship) between 1 and 80),
  guardian_email text not null check (char_length(guardian_email) between 3 and 254),
  guardian_phone text not null check (char_length(guardian_phone) between 7 and 40),
  alternate_phone text check (alternate_phone is null or char_length(alternate_phone) between 7 and 40),
  support_notes text check (support_notes is null or char_length(support_notes) <= 2000),
  status text not null default 'pending_review' check (status in ('pending_review', 'contacted', 'accepted', 'declined', 'withdrawn')),
  staff_notes text check (staff_notes is null or char_length(staff_notes) <= 2000),
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz
);
create index admission_applications_review_queue_idx on public.admission_applications(status, submitted_at desc);

create table public.admission_application_documents (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references public.admission_applications(id) on delete cascade,
  storage_path text not null unique check (storage_path ~ '^admissions/[0-9a-f-]{36}/[0-9a-f-]{36}$'),
  original_file_name text not null check (char_length(original_file_name) between 1 and 255),
  mime_type text not null check (mime_type in ('application/pdf', 'image/jpeg', 'image/png')),
  byte_size integer not null check (byte_size > 0 and byte_size <= 10485760),
  created_at timestamptz not null default now()
);
create index admission_application_documents_application_idx on public.admission_application_documents(application_id);

-- No browser role may read or mutate applicant data. Server Actions use the service
-- role only after validation; authenticated staff are constrained by people.manage.
revoke all on public.admission_applications, public.admission_application_documents from anon, authenticated;
grant select, update on public.admission_applications to authenticated;
grant select on public.admission_application_documents to authenticated;
alter table public.admission_applications enable row level security;
alter table public.admission_application_documents enable row level security;
create policy admission_applications_staff_review on public.admission_applications
  for all to authenticated using (app_private.has_admin_permission('people.manage')) with check (app_private.has_admin_permission('people.manage'));
create policy admission_application_documents_staff_review on public.admission_application_documents
  for select to authenticated using (app_private.has_admin_permission('people.manage'));

-- The existing bucket stays private. There are no browser storage policies for this
-- admissions prefix; downloads must be server-signed only after staff authorization.
