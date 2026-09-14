-- Private, server-mediated image storage. Content images are intentionally not in a
-- public bucket: only a route that confirms published content can sign a download.
alter table public.cms_pages add column image_path text;
alter table public.cms_news_posts add column image_path text;
alter table public.public_events add column image_path text;
alter table public.profiles add column avatar_path text;

-- Canonical UUID-form owner IDs and UUID-v4 object IDs prevent malformed or ambiguous object keys.
-- Existing row IDs may use any UUID version/variant; generated object IDs remain UUID-v4.
alter table public.cms_pages add constraint cms_pages_image_path_format check (image_path is null or image_path ~ '^content/page/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(jpg|png|webp)$');
alter table public.cms_news_posts add constraint cms_news_posts_image_path_format check (image_path is null or image_path ~ '^content/news/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(jpg|png|webp)$');
alter table public.public_events add constraint public_events_image_path_format check (image_path is null or image_path ~ '^content/event/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(jpg|png|webp)$');
alter table public.profiles add constraint profiles_avatar_path_format check (avatar_path is null or avatar_path ~ '^avatars/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(jpg|png|webp)$');

-- Bind every object key to the exact row it decorates. This prevents an editor
-- from attaching another record's private object through direct table access.
create function app_private.enforce_image_paths() returns trigger language plpgsql security definer set search_path = '' as $$
declare expected_prefix text;
begin
  if tg_table_name = 'profiles' then
    expected_prefix := 'avatars/' || new.id::text || '/';
  elsif tg_table_name = 'cms_pages' then
    expected_prefix := 'content/page/' || new.id::text || '/';
  elsif tg_table_name = 'cms_news_posts' then
    expected_prefix := 'content/news/' || new.id::text || '/';
  else
    expected_prefix := 'content/event/' || new.id::text || '/';
  end if;
  if tg_table_name = 'profiles' and (to_jsonb(new)->>'avatar_path') is not null and (to_jsonb(new)->>'avatar_path') not like expected_prefix || '%' then
    raise exception 'avatar object key must belong to this profile' using errcode = '23514';
  end if;
  if tg_table_name <> 'profiles' and (to_jsonb(new)->>'image_path') is not null and (to_jsonb(new)->>'image_path') not like expected_prefix || '%' then
    raise exception 'image object key must belong to this content record' using errcode = '23514';
  end if;
  return new;
end;
$$;
revoke all on function app_private.enforce_image_paths() from public, anon, authenticated;
create trigger profiles_image_path before insert or update of avatar_path on public.profiles for each row execute procedure app_private.enforce_image_paths();
create trigger cms_pages_image_path before insert or update of image_path on public.cms_pages for each row execute procedure app_private.enforce_image_paths();
create trigger cms_news_posts_image_path before insert or update of image_path on public.cms_news_posts for each row execute procedure app_private.enforce_image_paths();
create trigger public_events_image_path before insert or update of image_path on public.public_events for each row execute procedure app_private.enforce_image_paths();

-- Existing external avatar URLs are no longer rendered or editable. Preserve no
-- client-controlled image URL surface once uploads are enabled.
update public.profiles set avatar_url = null where avatar_url is not null;
revoke update (avatar_url) on public.profiles from authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('cms-images', 'cms-images', false, 5242880, array['image/jpeg', 'image/png', 'image/webp']),
  ('profile-avatars', 'profile-avatars', false, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = false, file_size_limit = 5242880, allowed_mime_types = excluded.allowed_mime_types;

-- No grants or storage.objects policies are created. Browser clients cannot list,
-- upload, update, delete, or read either bucket; server actions authorize each
-- transfer and issue narrowly scoped signed download URLs only after checking state.
