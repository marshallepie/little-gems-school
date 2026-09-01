-- Run after `supabase db reset --version 20260831000000`, before applying cutover.
-- Exercises the same one-time bootstrap function and migration-history sequencing
-- that production uses. These deterministic identities are local fixtures only.

-- The forward administrative-authorization migration, not the historical
-- foundation migration, supplies the required normalized portal roles.
do $$
begin
  if (select count(*) from public.roles where code in ('admin', 'teacher', 'parent', 'student')) <> 4 then
    raise exception 'forward administrative authorization migration did not seed all portal roles';
  end if;
end;
$$;

-- Empty baseline must fail before any policy changes.
do $$
begin
  begin
    perform app_private.assert_administrative_authorization_ready();
    raise exception 'empty baseline unexpectedly passed the authorization cutover gate';
  exception when raise_exception then
    if sqlerrm <> 'authorization cutover blocked: active proprietor_super_admin mapping for verified AdrianAnyata@marshallepie.com is required' then raise; end if;
  end;
end;
$$;

-- Missing identities cannot invoke the one-time bootstrap.
do $$
begin
  begin
    perform app_private.bootstrap_initial_production_administrators();
    raise exception 'missing identities unexpectedly bootstrapped';
  exception when check_violation then
    if sqlerrm <> 'initial production bootstrap requires exactly the approved three Auth users and no others' then raise; end if;
  end;
end;
$$;

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', 'b1000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'AdrianAnyata@marshallepie.com', '$2a$10$012345678901234567890u012345678901234567890123456789012', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'b1000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'R.Oses@marshallepie.com', '$2a$10$012345678901234567890u012345678901234567890123456789012', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'b1000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'G.I.Ucheya@marshallepie.com', '$2a$10$012345678901234567890u012345678901234567890123456789012', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now());

-- The function establishes profiles even if the Auth create trigger was absent for
-- pre-existing identities, then normalizes roles/positions and records verification.
select app_private.bootstrap_initial_production_administrators();
do $$
begin
  if (select count(*) from app_private.initial_production_bootstrap_verifications) <> 3 then raise exception 'bootstrap did not record three verifications'; end if;
  if (select count(*) from public.profiles where is_active and default_role_code = 'admin') <> 3 then raise exception 'bootstrap did not normalize three profiles'; end if;
  if (select count(*) from public.user_roles ur join public.roles r on r.id = ur.role_id where r.code = 'admin') <> 3 then raise exception 'bootstrap did not assign three admin roles'; end if;
  if (select count(*) from public.admin_position_assignments where revoked_at is null) <> 3 then raise exception 'bootstrap did not assign three positions'; end if;
  begin
    perform app_private.bootstrap_initial_production_administrators();
    raise exception 'completed bootstrap unexpectedly ran twice';
  exception when unique_violation then
    if sqlerrm <> 'initial production bootstrap has already completed; use normal proprietor workflows' then raise; end if;
  end;
end;
$$;
select app_private.assert_administrative_authorization_ready();
\echo 'PASS: administrative authorization cutover gate tests'
