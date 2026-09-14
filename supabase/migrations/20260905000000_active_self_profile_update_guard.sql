-- A valid JWT is not sufficient for contact updates after deprovisioning. Use a
-- SECURITY DEFINER helper to avoid self-referential RLS policy recursion while
-- preserving the self-only, column-granted initial profile-completion flow.
create function app_private.is_current_profile_active()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and is_active
  );
$$;

revoke all on function app_private.is_current_profile_active() from public, anon;
grant execute on function app_private.is_current_profile_active() to authenticated;

drop policy profiles_self_contact_update on public.profiles;
create policy profiles_self_contact_update on public.profiles for update to authenticated
  using (
    id = (select auth.uid())
    and app_private.is_current_profile_active()
  )
  with check (
    id = (select auth.uid())
    and app_private.is_current_profile_active()
  );
