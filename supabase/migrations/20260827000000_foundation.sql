-- Little Gems Phase 0 foundation. One school: deliberately no schools/school_id tenancy yet.
create extension if not exists pgcrypto;
create schema if not exists app_private;
revoke all on schema app_private from public, anon, authenticated;

create table public.roles (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code in ('admin', 'teacher', 'parent', 'student')),
  name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  phone text,
  default_role_code text check (default_role_code in ('admin', 'teacher', 'parent', 'student')),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.user_roles (
  user_id uuid not null references public.profiles(id) on delete cascade,
  role_id uuid not null references public.roles(id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key (user_id, role_id)
);
create table public.students (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid unique references public.profiles(id) on delete set null,
  admission_number text not null unique,
  first_name text not null,
  last_name text not null,
  date_of_birth date,
  status text not null default 'active' check (status in ('active', 'inactive', 'graduated')),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.teachers (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null unique references public.profiles(id) on delete restrict,
  staff_number text not null unique,
  first_name text not null, last_name text not null,
  employment_status text not null default 'active' check (employment_status in ('active', 'inactive')),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.guardians (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid unique references public.profiles(id) on delete set null,
  first_name text not null, last_name text not null, phone text not null, email text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.student_guardians (
  student_id uuid not null references public.students(id) on delete cascade,
  guardian_id uuid not null references public.guardians(id) on delete cascade,
  relationship text not null, is_primary_contact boolean not null default false,
  created_at timestamptz not null default now(),
  primary key (student_id, guardian_id)
);
create table public.academic_years (
  id uuid primary key default gen_random_uuid(), name text not null unique,
  starts_on date not null, ends_on date not null, is_current boolean not null default false,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check (ends_on > starts_on)
);
create unique index academic_years_one_current on public.academic_years (is_current) where is_current;
create table public.terms (
  id uuid primary key default gen_random_uuid(), academic_year_id uuid not null references public.academic_years(id) on delete restrict,
  name text not null, starts_on date not null, ends_on date not null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique (academic_year_id, name), check (ends_on > starts_on)
);
create table public.class_groups (
  id uuid primary key default gen_random_uuid(), academic_year_id uuid not null references public.academic_years(id) on delete restrict,
  name text not null, level text not null, homeroom_teacher_id uuid references public.teachers(id) on delete set null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique (academic_year_id, name)
);
create table public.subjects (
  id uuid primary key default gen_random_uuid(), code text not null unique, name text not null, is_active boolean not null default true,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.class_enrolments (
  id uuid primary key default gen_random_uuid(), student_id uuid not null references public.students(id) on delete restrict,
  class_group_id uuid not null references public.class_groups(id) on delete restrict,
  starts_on date not null, ends_on date, status text not null default 'active' check (status in ('active', 'withdrawn', 'completed')),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique(student_id, class_group_id, starts_on), check (ends_on is null or ends_on >= starts_on)
);
create table public.teacher_assignments (
  id uuid primary key default gen_random_uuid(), teacher_id uuid not null references public.teachers(id) on delete restrict,
  class_group_id uuid not null references public.class_groups(id) on delete restrict,
  subject_id uuid not null references public.subjects(id) on delete restrict,
  term_id uuid references public.terms(id) on delete restrict,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique nulls not distinct (teacher_id, class_group_id, subject_id, term_id)
);

create index student_guardians_guardian_student_idx on public.student_guardians(guardian_id, student_id);
create index class_enrolments_student_class_active_idx on public.class_enrolments(student_id, class_group_id) where status = 'active';
create index class_enrolments_class_student_active_idx on public.class_enrolments(class_group_id, student_id) where status = 'active';
create index teacher_assignments_teacher_class_subject_idx on public.teacher_assignments(teacher_id, class_group_id, subject_id);
create index terms_academic_year_idx on public.terms(academic_year_id);
create index class_groups_academic_year_idx on public.class_groups(academic_year_id);

create function app_private.set_updated_at() returns trigger language plpgsql security definer set search_path = '' as $$ begin new.updated_at = now(); return new; end; $$;
create function app_private.handle_new_user() returns trigger language plpgsql security definer set search_path = '' as $$ begin insert into public.profiles(id, display_name) values (new.id, coalesce(new.raw_user_meta_data ->> 'display_name', '')); return new; end; $$;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure app_private.handle_new_user();
create trigger roles_updated_at before update on public.roles for each row execute procedure app_private.set_updated_at();
create trigger profiles_updated_at before update on public.profiles for each row execute procedure app_private.set_updated_at();
create trigger students_updated_at before update on public.students for each row execute procedure app_private.set_updated_at();
create trigger teachers_updated_at before update on public.teachers for each row execute procedure app_private.set_updated_at();
create trigger guardians_updated_at before update on public.guardians for each row execute procedure app_private.set_updated_at();
create trigger academic_years_updated_at before update on public.academic_years for each row execute procedure app_private.set_updated_at();
create trigger terms_updated_at before update on public.terms for each row execute procedure app_private.set_updated_at();
create trigger class_groups_updated_at before update on public.class_groups for each row execute procedure app_private.set_updated_at();
create trigger subjects_updated_at before update on public.subjects for each row execute procedure app_private.set_updated_at();
create trigger class_enrolments_updated_at before update on public.class_enrolments for each row execute procedure app_private.set_updated_at();
create trigger teacher_assignments_updated_at before update on public.teacher_assignments for each row execute procedure app_private.set_updated_at();

create function app_private.has_role(required_role text) returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.user_roles ur join public.roles r on r.id = ur.role_id where ur.user_id = (select auth.uid()) and r.code = required_role);
$$;
create function app_private.is_guardian_of(target_student_id uuid) returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.guardians g join public.student_guardians sg on sg.guardian_id = g.id where g.profile_id = (select auth.uid()) and sg.student_id = target_student_id);
$$;
create function app_private.is_student_self(target_student_id uuid) returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.students s where s.id = target_student_id and s.profile_id = (select auth.uid()));
$$;
create function app_private.teaches_class(target_class_group_id uuid) returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.teachers t join public.teacher_assignments ta on ta.teacher_id = t.id where t.profile_id = (select auth.uid()) and ta.class_group_id = target_class_group_id);
$$;
create function app_private.teaches_subject_in_class(target_class_group_id uuid, target_subject_id uuid) returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.teachers t join public.teacher_assignments ta on ta.teacher_id = t.id where t.profile_id = (select auth.uid()) and ta.class_group_id = target_class_group_id and ta.subject_id = target_subject_id);
$$;
revoke all on all functions in schema app_private from public, anon;
grant usage on schema app_private to authenticated;
grant execute on function app_private.has_role(text), app_private.is_guardian_of(uuid), app_private.is_student_self(uuid), app_private.teaches_class(uuid), app_private.teaches_subject_in_class(uuid, uuid) to authenticated;
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant select on public.roles to anon;

alter table public.roles enable row level security;
alter table public.profiles enable row level security;
alter table public.user_roles enable row level security;
alter table public.students enable row level security;
alter table public.teachers enable row level security;
alter table public.guardians enable row level security;
alter table public.student_guardians enable row level security;
alter table public.academic_years enable row level security;
alter table public.terms enable row level security;
alter table public.class_groups enable row level security;
alter table public.subjects enable row level security;
alter table public.class_enrolments enable row level security;
alter table public.teacher_assignments enable row level security;

-- Default deny applies because every exposed table has RLS. These minimal policies only support the secure shell and academic reference reads.
create policy roles_read_authenticated on public.roles for select to authenticated using (true);
create policy profiles_own_or_admin_read on public.profiles for select to authenticated using (id = (select auth.uid()) or app_private.has_role('admin'));
create policy profiles_own_update on public.profiles for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()) and default_role_code is not distinct from (select p.default_role_code from public.profiles p where p.id = (select auth.uid())));
create policy user_roles_own_or_admin_read on public.user_roles for select to authenticated using (user_id = (select auth.uid()) or app_private.has_role('admin'));
create policy students_relationship_read on public.students for select to authenticated using (app_private.has_role('admin') or app_private.is_student_self(id) or app_private.is_guardian_of(id) or exists(select 1 from public.class_enrolments ce where ce.student_id = id and ce.status = 'active' and app_private.teaches_class(ce.class_group_id)));
create policy guardians_relationship_read on public.guardians for select to authenticated using (app_private.has_role('admin') or profile_id = (select auth.uid()) or exists(select 1 from public.student_guardians sg where sg.guardian_id = id and app_private.is_student_self(sg.student_id)));
create policy student_guardians_relationship_read on public.student_guardians for select to authenticated using (app_private.has_role('admin') or app_private.is_student_self(student_id) or app_private.is_guardian_of(student_id));
create policy academic_years_authenticated_read on public.academic_years for select to authenticated using (true);
create policy terms_authenticated_read on public.terms for select to authenticated using (true);
create policy class_groups_relationship_read on public.class_groups for select to authenticated using (app_private.has_role('admin') or app_private.teaches_class(id) or exists(select 1 from public.class_enrolments ce where ce.class_group_id = id and (app_private.is_student_self(ce.student_id) or app_private.is_guardian_of(ce.student_id))));
create policy subjects_authenticated_read on public.subjects for select to authenticated using (true);
create policy enrolments_relationship_read on public.class_enrolments for select to authenticated using (app_private.has_role('admin') or app_private.is_student_self(student_id) or app_private.is_guardian_of(student_id) or app_private.teaches_class(class_group_id));
create policy assignments_own_or_admin_read on public.teacher_assignments for select to authenticated using (app_private.has_role('admin') or exists(select 1 from public.teachers t where t.id = teacher_id and t.profile_id = (select auth.uid())));
