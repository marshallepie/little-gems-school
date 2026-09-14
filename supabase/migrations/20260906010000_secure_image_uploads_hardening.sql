-- Forward-only repair for already-applied secure image uploads. Keep profile writes
-- column-scoped and storage access server-mediated even if a prior deployment had
-- inherited table grants or permissive storage policies.

-- The profile action only writes the private object key. Clear any broad UPDATE
-- grants before restoring the existing self-contact fields and this one server field.
revoke update on table public.profiles from public, anon, authenticated, service_role;
grant update (display_name, phone, address, profile_completed_at) on table public.profiles to authenticated;
grant update (avatar_path) on table public.profiles to service_role;

-- Storage object grants are table-wide (and may be inherited through PUBLIC), so
-- changing them here would also change access to unrelated buckets. The targeted
-- restrictive policy below is the security boundary for these two image buckets.
-- Service actions retain their existing service_role path.

-- A restrictive policy remains effective even if an unrelated permissive policy is
-- introduced later. It prevents the two image buckets from being browser-readable
-- or browser-writable while leaving any future non-image storage policy independent.
drop policy if exists image_buckets_browser_deny on storage.objects;
create policy image_buckets_browser_deny on storage.objects
  as restrictive
  for all
  to anon, authenticated
  using (bucket_id not in ('cms-images', 'profile-avatars'))
  with check (bucket_id not in ('cms-images', 'profile-avatars'));
