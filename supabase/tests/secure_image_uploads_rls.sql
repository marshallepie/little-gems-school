begin;
-- Run after all migrations using scripts/db-behavioural-validate.sh. This checks
-- actual role permissions and RLS, not assumed default-deny behaviour.

-- The authorization-cutover fixture supplies this active owner profile.
do $$
begin
  if not has_column_privilege('service_role', 'public.profiles', 'avatar_path', 'UPDATE') then
    raise exception 'service_role lacks the required profiles.avatar_path UPDATE grant';
  end if;
  if has_column_privilege('service_role', 'public.profiles', 'display_name', 'UPDATE')
    or has_column_privilege('authenticated', 'public.profiles', 'avatar_path', 'UPDATE') then
    raise exception 'profiles avatar grant is broader than intended';
  end if;
end $$;

set local role service_role;
do $$
declare changed integer;
begin
  update public.profiles
    set avatar_path = 'avatars/b1000000-0000-0000-0000-000000000001/22222222-2222-4222-8222-222222222222.png'
    where id = 'b1000000-0000-0000-0000-000000000001';
  get diagnostics changed = row_count;
  if changed <> 1 then raise exception 'service_role could not update the owner avatar path'; end if;

  begin
    update public.profiles set display_name = 'service-role-overreach'
      where id = 'b1000000-0000-0000-0000-000000000001';
    raise exception 'service_role could update profiles.display_name';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', 'b1000000-0000-0000-0000-000000000001', true);
do $$
begin
  begin
    update public.profiles set avatar_path = 'avatars/b1000000-0000-0000-0000-000000000001/33333333-3333-4333-8333-333333333333.png'
      where id = 'b1000000-0000-0000-0000-000000000001';
    raise exception 'authenticated owner directly updated avatar_path';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

-- Seed known objects as the test owner, then exercise browser list, exact-object
-- read (the authorization used by direct Storage download), and all write verbs.
insert into storage.objects(bucket_id, name, owner, metadata) values
  ('cms-images', 'content/page/11111111-1111-4111-8111-111111111111/22222222-2222-4222-8222-222222222222.png', 'b1000000-0000-0000-0000-000000000001', '{}'::jsonb),
  ('profile-avatars', 'avatars/11111111-1111-4111-8111-111111111111/22222222-2222-4222-8222-222222222222.png', 'b1000000-0000-0000-0000-000000000001', '{}'::jsonb);

-- storage.objects grants are table-wide and can be inherited through PUBLIC. They
-- do not identify access to one bucket, so verify the restrictive bucket policy
-- and then exercise the actual browser operations below.
do $$
declare policy_is_permissive boolean; policy_command "char"; policy_roles text[];
  policy_qual text; policy_with_check text;
begin
  select p.polpermissive, p.polcmd,
      array(select r.rolname from pg_roles r where r.oid = any(p.polroles) order by r.rolname),
      pg_get_expr(p.polqual, p.polrelid), pg_get_expr(p.polwithcheck, p.polrelid)
    into policy_is_permissive, policy_command, policy_roles, policy_qual, policy_with_check
    from pg_policy p
    where p.polrelid = 'storage.objects'::regclass and p.polname = 'image_buckets_browser_deny';

  if policy_is_permissive is distinct from false
    or policy_command is distinct from '*'
    or policy_roles is distinct from array['anon', 'authenticated']
    or policy_qual is null
    or policy_with_check is null
    or policy_qual !~ 'bucket_id.*cms-images.*profile-avatars'
    or policy_with_check !~ 'bucket_id.*cms-images.*profile-avatars' then
    raise exception 'image bucket deny policy is missing, not restrictive, or not scoped to both private image buckets';
  end if;
end $$;

set local role anon;
do $$
declare bucket text; object_name text; n integer;
begin
  foreach bucket in array array['cms-images', 'profile-avatars'] loop
    object_name := case bucket
      when 'cms-images' then 'content/page/11111111-1111-4111-8111-111111111111/22222222-2222-4222-8222-222222222222.png'
      else 'avatars/11111111-1111-4111-8111-111111111111/22222222-2222-4222-8222-222222222222.png'
    end;

    begin
      select count(*) into n from storage.objects where bucket_id = bucket;
      if n <> 0 then raise exception 'anonymous browser listed % object(s) in %', n, bucket; end if;
    exception when insufficient_privilege then null;
    end;
    begin
      select count(*) into n from storage.objects where bucket_id = bucket and name = object_name;
      if n <> 0 then raise exception 'anonymous browser read/downloaded an object in %', bucket; end if;
    exception when insufficient_privilege then null;
    end;
    begin
      insert into storage.objects(bucket_id, name, owner, metadata)
        values (bucket, object_name || '.anon-new', null, '{}'::jsonb);
      raise exception 'anonymous browser inserted an object in %', bucket;
    exception when insufficient_privilege then null;
    end;
    begin
      update storage.objects set metadata = '{"tampered":true}'::jsonb where bucket_id = bucket and name = object_name;
      get diagnostics n = row_count;
      if n <> 0 then raise exception 'anonymous browser updated an object in %', bucket; end if;
    exception when insufficient_privilege then null;
    end;
    begin
      delete from storage.objects where bucket_id = bucket and name = object_name;
      get diagnostics n = row_count;
      if n <> 0 then raise exception 'anonymous browser deleted an object in %', bucket; end if;
    exception when insufficient_privilege then null;
    end;
  end loop;
end $$;
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', 'b1000000-0000-0000-0000-000000000001', true);
do $$
declare bucket text; object_name text; n integer;
begin
  foreach bucket in array array['cms-images', 'profile-avatars'] loop
    object_name := case bucket
      when 'cms-images' then 'content/page/11111111-1111-4111-8111-111111111111/22222222-2222-4222-8222-222222222222.png'
      else 'avatars/11111111-1111-4111-8111-111111111111/22222222-2222-4222-8222-222222222222.png'
    end;

    begin
      select count(*) into n from storage.objects where bucket_id = bucket;
      if n <> 0 then raise exception 'authenticated browser listed % object(s) in %', n, bucket; end if;
    exception when insufficient_privilege then null;
    end;
    begin
      select count(*) into n from storage.objects where bucket_id = bucket and name = object_name;
      if n <> 0 then raise exception 'authenticated browser read/downloaded an object in %', bucket; end if;
    exception when insufficient_privilege then null;
    end;
    begin
      insert into storage.objects(bucket_id, name, owner, metadata)
        values (bucket, object_name || '.new', auth.uid(), '{}'::jsonb);
      raise exception 'authenticated browser inserted an object in %', bucket;
    exception when insufficient_privilege then null;
    end;
    begin
      update storage.objects set metadata = '{"tampered":true}'::jsonb where bucket_id = bucket and name = object_name;
      get diagnostics n = row_count;
      if n <> 0 then raise exception 'authenticated browser updated an object in %', bucket; end if;
    exception when insufficient_privilege then null;
    end;
    begin
      delete from storage.objects where bucket_id = bucket and name = object_name;
      get diagnostics n = row_count;
      if n <> 0 then raise exception 'authenticated browser deleted an object in %', bucket; end if;
    exception when insufficient_privilege then null;
    end;
  end loop;
end $$;
reset role;

do $$
begin
  if (select count(*) from storage.objects where bucket_id in ('cms-images', 'profile-avatars')) <> 2 then
    raise exception 'browser storage operation changed private image object state';
  end if;
  if (select public from storage.buckets where id = 'cms-images')
    or (select public from storage.buckets where id = 'profile-avatars') then
    raise exception 'image bucket is public';
  end if;
end $$;
rollback;
\echo 'PASS: secure image storage, profile avatar grants, and browser-deny behaviour'
