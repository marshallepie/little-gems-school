-- Admission applicant PII is accessed only by server actions after permission checks.
-- This is forward-only because 20260903000000 has already been applied.
revoke all on table public.admission_applications, public.admission_application_documents from anon, authenticated;
drop policy if exists admission_applications_staff_review on public.admission_applications;
drop policy if exists admission_application_documents_staff_review on public.admission_application_documents;

-- The server-only service client performs validated public submissions and
-- authorised staff review after the application has checked people.manage.
grant select, insert, update on table public.admission_applications to service_role;
grant select, insert on table public.admission_application_documents to service_role;
grant usage on schema app_private to service_role;
grant execute on function app_private.new_admission_application_reference() to service_role;
