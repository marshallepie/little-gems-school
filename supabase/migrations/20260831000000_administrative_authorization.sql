-- Administrative authorization hierarchy. This migration is additive but deliberately
-- replaces every broad `has_role('admin')` policy predicate; permissive RLS policies
-- OR-combine, so adding permission policies without dropping the legacy policies would
-- not be a cutover.

-- This forward-only seed intentionally repairs projects whose already-recorded
-- foundation migration pre-dated portal-role seeding, as well as fresh projects.
insert into public.roles (code, name) values
  ('admin', 'Administrator'),
  ('teacher', 'Teacher'),
  ('parent', 'Parent / Guardian'),
  ('student', 'Student')
on conflict (code) do update set name = excluded.name;

create table public.admin_positions (
  code text primary key check (code in ('proprietor_super_admin', 'senior_administrator', 'headmistress')),
  tier smallint not null unique check (tier between 1 and 3),
  name text not null,
  created_at timestamptz not null default now()
);

create table public.admin_permissions (
  code text primary key,
  name text not null,
  created_at timestamptz not null default now()
);

create table public.admin_position_permissions (
  position_code text not null references public.admin_positions(code) on delete cascade,
  permission_code text not null references public.admin_permissions(code) on delete cascade,
  primary key (position_code, permission_code)
);

create table public.admin_position_assignments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  position_code text not null references public.admin_positions(code) on delete restrict,
  assigned_at timestamptz not null default now(),
  assigned_by uuid references public.profiles(id) on delete set null,
  revoked_at timestamptz,
  revoked_by uuid references public.profiles(id) on delete set null,
  check ((revoked_at is null) = (revoked_by is null))
);
create unique index admin_position_assignments_one_active_per_admin
  on public.admin_position_assignments(user_id) where revoked_at is null;

-- Authorization/security events are append-only. Payload intentionally contains no
-- pupil, guardian, or other operational data.
create table public.authorization_events (
  id uuid primary key default gen_random_uuid(),
  occurred_at timestamptz not null default now(),
  actor_user_id uuid references public.profiles(id) on delete set null,
  subject_user_id uuid references public.profiles(id) on delete set null,
  event_type text not null check (event_type in ('position_assigned', 'position_revoked', 'role_assigned', 'role_revoked')),
  position_code text,
  role_code text,
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object')
);

-- Private, append-only evidence of the one approved production bootstrap. It
-- stores verified identities and positions only—never passwords, tokens, or
-- Auth metadata.
create table app_private.initial_production_bootstrap_verifications (
  user_id uuid primary key references public.profiles(id) on delete restrict,
  approved_email text not null unique check (approved_email in (
    'AdrianAnyata@marshallepie.com', 'R.Oses@marshallepie.com', 'G.I.Ucheya@marshallepie.com'
  )),
  position_code text not null references public.admin_positions(code) on delete restrict,
  verified_at timestamptz not null default now(),
  verified_by text not null default session_user
);
create table app_private.initial_production_bootstrap_state (
  singleton boolean primary key default true check (singleton),
  completed_at timestamptz not null default now(),
  completed_by text not null default session_user
);

insert into public.admin_positions (code, tier, name) values
  ('proprietor_super_admin', 1, 'Proprietor / Super Administrator'),
  ('senior_administrator', 2, 'Senior Administrator'),
  ('headmistress', 3, 'Headmistress')
on conflict (code) do update set tier = excluded.tier, name = excluded.name;

insert into public.admin_permissions (code, name) values
  ('authorization.manage', 'Manage administrator positions and review authorization events'),
  ('people.manage', 'Manage student, guardian, teacher, and relationship records'),
  ('academic_structure.manage', 'Manage academic years, terms, classes, and subjects'),
  ('enrolments.manage', 'Manage class enrolments'),
  ('teacher_assignments.manage', 'Manage teacher assignments'),
  ('school_records.read', 'Read Phase 1 school records')
on conflict (code) do update set name = excluded.name;

insert into public.admin_position_permissions (position_code, permission_code) values
  ('proprietor_super_admin', 'authorization.manage'),
  ('proprietor_super_admin', 'people.manage'),
  ('proprietor_super_admin', 'academic_structure.manage'),
  ('proprietor_super_admin', 'enrolments.manage'),
  ('proprietor_super_admin', 'teacher_assignments.manage'),
  ('proprietor_super_admin', 'school_records.read'),
  ('senior_administrator', 'people.manage'),
  ('senior_administrator', 'academic_structure.manage'),
  ('senior_administrator', 'enrolments.manage'),
  ('senior_administrator', 'teacher_assignments.manage'),
  ('senior_administrator', 'school_records.read'),
  ('headmistress', 'academic_structure.manage'),
  ('headmistress', 'enrolments.manage'),
  ('headmistress', 'teacher_assignments.manage'),
  ('headmistress', 'school_records.read')
on conflict do nothing;

create function app_private.has_admin_position(required_position text)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.admin_position_assignments apa
    join public.profiles p on p.id = apa.user_id and p.is_active
    where apa.user_id = (select auth.uid())
      and apa.position_code = required_position
      and apa.revoked_at is null
      and app_private.has_role('admin')
  );
$$;

create function app_private.has_admin_permission(required_permission text)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.admin_position_assignments apa
    join public.profiles p on p.id = apa.user_id and p.is_active
    join public.admin_position_permissions app on app.position_code = apa.position_code
    where apa.user_id = (select auth.uid())
      and apa.revoked_at is null
      and app.permission_code = required_permission
      and app_private.has_role('admin')
  );
$$;

-- Exposed only as a boolean RPC for server guards; it does not disclose mappings.
create function public.has_admin_permission(required_permission text)
returns boolean language sql stable security definer set search_path = '' as $$
  select app_private.has_admin_permission(required_permission);
$$;

create function app_private.record_authorization_event()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := (select auth.uid());
  role_code_value text;
begin
  if tg_table_name = 'admin_position_assignments' then
    if tg_op = 'INSERT' then
      insert into public.authorization_events(actor_user_id, subject_user_id, event_type, position_code)
      values (coalesce(actor, new.assigned_by), new.user_id, 'position_assigned', new.position_code);
    elsif old.revoked_at is null and new.revoked_at is not null then
      insert into public.authorization_events(actor_user_id, subject_user_id, event_type, position_code)
      values (coalesce(actor, new.revoked_by), new.user_id, 'position_revoked', old.position_code);
    end if;
  elsif tg_table_name = 'user_roles' then
    select code into role_code_value from public.roles where id = coalesce(new.role_id, old.role_id);
    insert into public.authorization_events(actor_user_id, subject_user_id, event_type, role_code)
    values (actor, coalesce(new.user_id, old.user_id), case when tg_op = 'INSERT' then 'role_assigned' else 'role_revoked' end, role_code_value);
  end if;
  return coalesce(new, old);
end;
$$;

create trigger admin_position_assignments_audit
  after insert or update of revoked_at, revoked_by on public.admin_position_assignments
  for each row execute procedure app_private.record_authorization_event();
create trigger user_roles_authorization_audit
  after insert or delete on public.user_roles
  for each row execute procedure app_private.record_authorization_event();

-- Only a verified proprietor can delegate Tier 2/3. The proprietor position itself
-- is bootstrap-only and cannot be changed through this callable path.
create function app_private.set_admin_position(target_user_id uuid, target_position_code text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := (select auth.uid());
begin
  if not app_private.has_admin_permission('authorization.manage') then
    raise exception 'not authorized to manage administrator positions' using errcode = '42501';
  end if;
  if target_position_code = 'proprietor_super_admin' then
    raise exception 'proprietor position is bootstrap-only' using errcode = '42501';
  end if;
  if not exists (select 1 from auth.users where id = target_user_id) then
    raise exception 'target must be a verified Supabase Auth identity' using errcode = '23503';
  end if;
  if not exists (select 1 from public.user_roles ur join public.roles r on r.id = ur.role_id where ur.user_id = target_user_id and r.code = 'admin') then
    raise exception 'target must have the existing admin portal role before receiving a position' using errcode = '23514';
  end if;
  if exists (select 1 from public.admin_position_assignments where user_id = target_user_id and position_code = 'proprietor_super_admin' and revoked_at is null) then
    raise exception 'the proprietor position cannot be modified through delegation' using errcode = '42501';
  end if;
  update public.admin_position_assignments set revoked_at = now(), revoked_by = actor where user_id = target_user_id and revoked_at is null;
  insert into public.admin_position_assignments(user_id, position_code, assigned_by) values (target_user_id, target_position_code, actor);
end;
$$;

-- This is the single fail-closed gate shared by the cutover migration and local
-- behavioural tests. It is deliberately installed before the later cutover
-- migration: a normal `supabase db push` can persist this protected bootstrap
-- capability, but cannot silently proceed to the policy replacement without a
-- reviewed proprietor mapping.
create function app_private.assert_administrative_authorization_ready()
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not exists (
    select 1
    from public.admin_position_assignments apa
    join public.profiles p on p.id = apa.user_id
      and p.is_active
      and p.default_role_code = 'admin'
    join public.user_roles ur on ur.user_id = apa.user_id
    join public.roles r on r.id = ur.role_id and r.code = 'admin'
    join auth.users u on u.id = apa.user_id
      and lower(u.email::text) = lower('AdrianAnyata@marshallepie.com')
    where apa.position_code = 'proprietor_super_admin'
      and apa.revoked_at is null
  ) then
    raise exception 'authorization cutover blocked: active proprietor_super_admin mapping for verified AdrianAnyata@marshallepie.com is required';
  end if;

  if exists (
    select 1
    from public.user_roles ur
    join public.roles r on r.id = ur.role_id and r.code = 'admin'
    join public.profiles p on p.id = ur.user_id and p.is_active
    where not exists (
      select 1 from public.admin_position_assignments apa
      where apa.user_id = ur.user_id and apa.revoked_at is null
    )
  ) then
    raise exception 'authorization cutover blocked: every active existing admin must have an active position';
  end if;
end;
$$;

-- One-time initial-production cutover step. Auth identities are created separately
-- through the server-only Admin API; this function only verifies the exact approved
-- three-account set, repairs missing trigger profiles, and atomically normalizes
-- application-side mappings. It has no UUID parameter and cannot provision a
-- replacement account or be rerun after its invariant marker is written.
create function app_private.bootstrap_initial_production_administrators()
returns void language plpgsql security definer set search_path = '' as $$
declare
  approved record;
  target_id uuid;
  admin_role_id uuid;
begin
  if session_user not in ('postgres', 'supabase_admin') then
    raise exception 'bootstrap is restricted to the database operator' using errcode = '42501';
  end if;
  if exists (select 1 from app_private.initial_production_bootstrap_state) then
    raise exception 'initial production bootstrap has already completed; use normal proprietor workflows' using errcode = '23505';
  end if;
  if (select count(*) from auth.users) <> 3 then
    raise exception 'initial production bootstrap requires exactly the approved three Auth users and no others' using errcode = '23514';
  end if;
  if exists (select 1 from public.user_roles) or exists (select 1 from public.admin_position_assignments) then
    raise exception 'initial production bootstrap requires no existing role or position assignments' using errcode = '23514';
  end if;
  select id into strict admin_role_id from public.roles where code = 'admin';

  for approved in select * from (values
    ('AdrianAnyata@marshallepie.com'::text, 'proprietor_super_admin'::text),
    ('R.Oses@marshallepie.com'::text, 'senior_administrator'::text),
    ('G.I.Ucheya@marshallepie.com'::text, 'headmistress'::text)
  ) as expected(email, position_code) loop
    select id into strict target_id from auth.users
      where lower(email::text) = lower(approved.email)
        and email_confirmed_at is not null
        and (banned_until is null or banned_until <= now());
    -- Covers a missing or legacy pre-trigger profile without touching Auth data.
    insert into public.profiles(id, display_name, default_role_code, is_active)
      values (target_id, '', 'admin', true)
      on conflict (id) do update set default_role_code = 'admin', is_active = true;
    insert into public.user_roles(user_id, role_id) values (target_id, admin_role_id);
    insert into public.admin_position_assignments(user_id, position_code)
      values (target_id, approved.position_code);
    insert into app_private.initial_production_bootstrap_verifications(user_id, approved_email, position_code)
      values (target_id, approved.email, approved.position_code);
  end loop;
  if (select count(*) from app_private.initial_production_bootstrap_verifications) <> 3 then
    raise exception 'initial production bootstrap did not establish all three verification records' using errcode = '23514';
  end if;
  insert into app_private.initial_production_bootstrap_state default values;
end;
$$;

revoke all on function public.has_admin_permission(text) from public, anon;
revoke all on function app_private.record_authorization_event(), app_private.assert_administrative_authorization_ready(), app_private.bootstrap_initial_production_administrators() from public, anon, authenticated, service_role;
revoke all on function app_private.has_admin_position(text), app_private.has_admin_permission(text), app_private.set_admin_position(uuid, text) from public, anon;
grant execute on function public.has_admin_permission(text), app_private.has_admin_position(text), app_private.has_admin_permission(text), app_private.set_admin_position(uuid, text) to authenticated;

-- Direct mutation bypasses the protected function paths, so explicitly revoke the
-- broad foundation table grants and leave RLS default-deny on administration tables.
revoke all on public.roles, public.user_roles, public.admin_positions, public.admin_permissions, public.admin_position_permissions, public.admin_position_assignments, public.authorization_events from authenticated;
revoke all on app_private.initial_production_bootstrap_verifications, app_private.initial_production_bootstrap_state from public, anon, authenticated, service_role;
grant select on public.roles, public.user_roles to authenticated;
alter table public.admin_positions enable row level security;
alter table public.admin_permissions enable row level security;
alter table public.admin_position_permissions enable row level security;
alter table public.admin_position_assignments enable row level security;
alter table public.authorization_events enable row level security;
create policy admin_position_assignments_self_read on public.admin_position_assignments for select to authenticated using (user_id = (select auth.uid()));
