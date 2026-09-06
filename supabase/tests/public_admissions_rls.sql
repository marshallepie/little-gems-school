-- Public admissions migration behavioural tests. Run after the authorization fixture
-- and the full migration chain; this file leaves the disposable stack unchanged.
begin;
insert into public.admission_applications (
  id, application_reference, child_first_name, child_last_name, child_date_of_birth,
  requested_class, guardian_first_name, guardian_last_name, guardian_relationship,
  guardian_email, guardian_phone
) values (
  '17000000-0000-0000-0000-000000000001', 'LG-TEST-PRIVATE', 'Private', 'Applicant', '2021-01-01',
  'Nursery 1', 'Test', 'Guardian', 'Mother', 'applicant@example.test', '0000000'
);
insert into public.admission_application_documents (id, application_id, storage_path, original_file_name, mime_type, byte_size)
values ('18000000-0000-0000-0000-000000000001', '17000000-0000-0000-0000-000000000001', 'admissions/17000000-0000-0000-0000-000000000001/18000000-0000-0000-0000-000000000001', 'private.pdf', 'application/pdf', 10);

set local role anon;
do $$ begin
  begin
    perform 1 from public.admission_applications;
    raise exception 'anon read private admissions data';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

set local role authenticated;
-- Even a reviewer with people.manage cannot directly query or mutate applicant PII.
-- The server action authorizes this identity before using service_role instead.
select set_config('request.jwt.claim.sub', 'b1000000-0000-0000-0000-000000000002', true);
do $$ begin
  begin
    perform 1 from public.admission_applications;
    raise exception 'authenticated reviewer directly read private applications';
  exception when insufficient_privilege then null;
  end;
  begin
    perform 1 from public.admission_application_documents;
    raise exception 'authenticated reviewer directly read private document metadata';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.admission_applications set status = 'accepted', staff_notes = 'Bypass attempt' where id = '17000000-0000-0000-0000-000000000001';
    raise exception 'authenticated reviewer directly updated private application';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

-- The server-only service client retains the data access needed after its
-- application-level authorization and validation checks.
set local role service_role;
do $$ begin
  if not exists(select 1 from public.admission_applications where application_reference = 'LG-TEST-PRIVATE') then raise exception 'service role cannot read application'; end if;
  if not exists(select 1 from public.admission_application_documents where application_id = '17000000-0000-0000-0000-000000000001') then raise exception 'service role cannot read document metadata'; end if;
end $$;
update public.admission_applications set status = 'accepted', staff_notes = 'Reviewed' where id = '17000000-0000-0000-0000-000000000001';
do $$ begin
  if not exists(select 1 from public.admission_applications where id = '17000000-0000-0000-0000-000000000001' and status = 'accepted') then raise exception 'service role review update failed'; end if;
end $$;
reset role;

do $$ begin
  if exists(select 1 from public.students where first_name = 'Private' and last_name = 'Applicant') then raise exception 'admission review created enrolled student'; end if;
end $$;
rollback;
\echo 'PASS: public admissions private RLS and staff review tests'
