-- Secretary-scoped CMS editing and administrator-only publication. This migration is
-- uncommitted/unapplied, so it deliberately replaces the initial CMS workflow design.
alter table public.roles drop constraint roles_code_check;
alter table public.roles add constraint roles_code_check check (code in ('admin', 'teacher', 'parent', 'student', 'secretary'));
alter table public.profiles drop constraint profiles_default_role_code_check;
alter table public.profiles add constraint profiles_default_role_code_check check (default_role_code in ('admin', 'teacher', 'parent', 'student', 'secretary'));
insert into public.roles (code, name) values ('secretary', 'Secretary') on conflict (code) do update set name = excluded.name;

insert into public.admin_permissions (code, name) values
  ('website_content.edit', 'Create and edit website content drafts'),
  ('website_content.publish', 'Publish website content')
on conflict (code) do update set name = excluded.name;
insert into public.admin_position_permissions (position_code, permission_code) values
  ('proprietor_super_admin', 'website_content.edit'), ('proprietor_super_admin', 'website_content.publish'),
  ('senior_administrator', 'website_content.edit'), ('senior_administrator', 'website_content.publish'),
  ('headmistress', 'website_content.edit')
on conflict do nothing;

create table public.website_content_editor_assignments (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  assigned_at timestamptz not null default now(),
  assigned_by uuid not null references public.profiles(id) on delete restrict
);
alter table public.website_content_editor_assignments enable row level security;
revoke all on public.website_content_editor_assignments from public, anon, authenticated;
-- The server-rendered account lifecycle page needs membership only, not assignment provenance.
grant select (user_id) on table public.website_content_editor_assignments to service_role;

create function app_private.has_secretary_website_content_editor_assignment()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.website_content_editor_assignments e
    join public.profiles p on p.id = e.user_id and p.is_active
    join public.user_roles ur on ur.user_id = e.user_id
    join public.roles r on r.id = ur.role_id and r.code = 'secretary'
    where e.user_id = (select auth.uid())
  );
$$;
create function app_private.has_website_content_edit_permission()
returns boolean language sql stable security definer set search_path = '' as $$
  select app_private.has_admin_permission('website_content.edit')
      or app_private.has_secretary_website_content_editor_assignment();
$$;
create function public.has_website_content_edit_permission()
returns boolean language sql stable security definer set search_path = '' as $$
  select app_private.has_website_content_edit_permission();
$$;

-- Service-role only: browser authorization is checked before this call. The audit
-- event records only actor, subject, and capability event type; no credentials/payload.
create function public.set_website_content_editor_from_server(target_user_id uuid, actor_user_id uuid, enabled boolean)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not exists (
    select 1 from public.admin_position_assignments apa
    join public.profiles actor on actor.id = apa.user_id and actor.is_active
    join public.user_roles ur on ur.user_id = actor.id
    join public.roles r on r.id = ur.role_id and r.code = 'admin'
    where apa.user_id = actor_user_id and apa.position_code = 'proprietor_super_admin' and apa.revoked_at is null
  ) then raise exception 'only the proprietor can manage secretary website editors' using errcode = '42501'; end if;
  if not exists (
    select 1 from public.profiles p join public.user_roles ur on ur.user_id = p.id join public.roles r on r.id = ur.role_id and r.code = 'secretary'
    where p.id = target_user_id and p.is_active
  ) then raise exception 'website editor assignment requires an active secretary account' using errcode = '23514'; end if;
  if enabled then
    insert into public.website_content_editor_assignments(user_id, assigned_by) values (target_user_id, actor_user_id)
    on conflict (user_id) do update set assigned_at = now(), assigned_by = excluded.assigned_by;
    insert into public.authorization_events(actor_user_id, subject_user_id, event_type) values (actor_user_id, target_user_id, 'website_content_editor_granted');
  else
    delete from public.website_content_editor_assignments where user_id = target_user_id;
    insert into public.authorization_events(actor_user_id, subject_user_id, event_type) values (actor_user_id, target_user_id, 'website_content_editor_revoked');
  end if;
end;
$$;
revoke all on function public.has_website_content_edit_permission(), public.set_website_content_editor_from_server(uuid, uuid, boolean) from public, anon, authenticated;
grant execute on function public.has_website_content_edit_permission() to authenticated;
grant execute on function public.set_website_content_editor_from_server(uuid, uuid, boolean) to service_role;

alter table public.authorization_events drop constraint authorization_events_event_type_check;
alter table public.authorization_events add constraint authorization_events_event_type_check check (event_type in (
  'position_assigned', 'position_revoked', 'role_assigned', 'role_revoked', 'account_created', 'account_deprovisioned', 'account_auth_ban_failed', 'account_auth_ban_completed',
  'website_content_editor_granted', 'website_content_editor_revoked'
));

-- One URL can have many private versions, but exactly one public version. Archived
-- versions retain the prior published history and are never visible to public RLS.
alter table public.cms_pages drop constraint cms_pages_slug_key, drop constraint cms_pages_status_check, drop constraint cms_pages_check;
alter table public.cms_news_posts drop constraint cms_news_posts_slug_key, drop constraint cms_news_posts_status_check, drop constraint cms_news_posts_check;
alter table public.public_events drop constraint public_events_slug_key, drop constraint public_events_status_check, drop constraint public_events_check;
alter table public.cms_pages add column version integer not null default 1 check (version >= 1), add column last_edited_by uuid references public.profiles(id) on delete set null, add column published_by uuid references public.profiles(id) on delete set null, add column replaces_id uuid references public.cms_pages(id) on delete restrict;
alter table public.cms_news_posts add column version integer not null default 1 check (version >= 1), add column last_edited_by uuid references public.profiles(id) on delete set null, add column published_by uuid references public.profiles(id) on delete set null, add column replaces_id uuid references public.cms_news_posts(id) on delete restrict;
alter table public.public_events add column version integer not null default 1 check (version >= 1), add column last_edited_by uuid references public.profiles(id) on delete set null, add column published_by uuid references public.profiles(id) on delete set null, add column replaces_id uuid references public.public_events(id) on delete restrict;
alter table public.cms_pages add constraint cms_pages_status_check check (status in ('draft', 'published', 'archived')), add constraint cms_pages_publication_check check ((status = 'draft' and published_at is null and published_by is null) or (status in ('published', 'archived') and published_at is not null and published_by is not null));
alter table public.cms_news_posts add constraint cms_news_posts_status_check check (status in ('draft', 'published', 'archived')), add constraint cms_news_posts_publication_check check ((status = 'draft' and published_at is null and published_by is null) or (status in ('published', 'archived') and published_at is not null and published_by is not null));
alter table public.public_events add constraint public_events_status_check check (status in ('draft', 'published', 'archived')), add constraint public_events_publication_check check ((status = 'draft' and published_at is null and published_by is null) or (status in ('published', 'archived') and published_at is not null and published_by is not null));
create unique index cms_pages_one_published_slug on public.cms_pages(slug) where status = 'published';
create unique index cms_news_posts_one_published_slug on public.cms_news_posts(slug) where status = 'published';
create unique index public_events_one_published_slug on public.public_events(slug) where status = 'published';

create function app_private.enforce_website_content_workflow()
returns trigger language plpgsql security definer set search_path = '' as $$
declare actor uuid := (select auth.uid()); prior record; prior_rows bigint;
begin
  if not app_private.has_website_content_edit_permission() then raise exception 'website_content.edit permission is required' using errcode = '42501'; end if;
  if tg_op = 'INSERT' then
    if new.status <> 'draft' or new.published_at is not null or new.published_by is not null then raise exception 'new website content must be saved as a draft' using errcode = '42501'; end if;
    new.created_by = actor; new.last_edited_by = actor;
    execute format('select id, slug, status, version from %I.%I where slug = $1 and status = ''published''', tg_table_schema, tg_table_name) into prior using new.slug;
    get diagnostics prior_rows = row_count;
    if prior_rows > 0 then
      if new.replaces_id is distinct from prior.id then raise exception 'a draft sharing an active published slug must replace that exact version' using errcode = '23514'; end if;
      new.version = prior.version + 1;
    elsif new.replaces_id is not null then
      execute format('select slug, status, version from %I.%I where id = $1', tg_table_schema, tg_table_name) into prior using new.replaces_id;
      get diagnostics prior_rows = row_count;
      if prior_rows = 0 or prior.status <> 'published' or prior.slug <> new.slug then raise exception 'replacement draft must reference the active published version for the same slug' using errcode = '23514'; end if;
      new.version = prior.version + 1;
    else new.version = 1; end if;
    return new;
  end if;
  if new.created_by is distinct from old.created_by or new.replaces_id is distinct from old.replaces_id then raise exception 'content authorship and replacement history are immutable' using errcode = '42501'; end if;
  if old.status = 'published' then
    if new.status = 'archived' and pg_trigger_depth() > 1 and app_private.has_admin_permission('website_content.publish') then return new; end if;
    raise exception 'published content cannot be altered or deleted; publish a replacement draft' using errcode = '42501';
  end if;
  if old.status = 'archived' then raise exception 'archived content cannot be altered' using errcode = '42501'; end if;
  if new.status = 'published' then
    if not app_private.has_admin_permission('website_content.publish') then raise exception 'website_content.publish permission is required' using errcode = '42501'; end if;
    if new.replaces_id is not null then
      execute format('update %I.%I set status = ''archived'' where id = $1 and slug = $2 and status = ''published''', tg_table_schema, tg_table_name) using new.replaces_id, new.slug;
      get diagnostics prior_rows = row_count;
      if prior_rows = 0 then raise exception 'replacement draft no longer references the active published version' using errcode = '23514'; end if;
    else
      execute format('select id from %I.%I where slug = $1 and status = ''published'' and id <> $2', tg_table_schema, tg_table_name) into prior using new.slug, new.id;
      get diagnostics prior_rows = row_count;
      if prior_rows > 0 then raise exception 'a colliding draft must replace the active published version' using errcode = '23514'; end if;
    end if;
    new.published_at = now(); new.published_by = actor;
  elsif new.status = 'draft' then
    if new.slug is distinct from old.slug then
      execute format('select id from %I.%I where slug = $1 and status = ''published''', tg_table_schema, tg_table_name) into prior using new.slug;
      get diagnostics prior_rows = row_count;
      if prior_rows > 0 and new.replaces_id is distinct from prior.id then raise exception 'a draft sharing an active published slug must replace that exact version' using errcode = '23514'; end if;
    end if;
  else raise exception 'draft content cannot have publication metadata' using errcode = '42501'; end if;
  new.last_edited_by = actor; new.version = old.version + 1; return new;
end;
$$;
revoke all on function app_private.enforce_website_content_workflow() from public, anon, authenticated;
drop trigger cms_pages_created_by on public.cms_pages; drop trigger cms_news_posts_created_by on public.cms_news_posts; drop trigger public_events_created_by on public.public_events;
create trigger cms_pages_content_workflow before insert or update on public.cms_pages for each row execute procedure app_private.enforce_website_content_workflow();
create trigger cms_news_posts_content_workflow before insert or update on public.cms_news_posts for each row execute procedure app_private.enforce_website_content_workflow();
create trigger public_events_content_workflow before insert or update on public.public_events for each row execute procedure app_private.enforce_website_content_workflow();

-- Replace broad website.manage policies with operation-specific, draft-only rules.
drop policy cms_pages_admin_write on public.cms_pages; drop policy cms_news_posts_admin_write on public.cms_news_posts; drop policy public_events_admin_write on public.public_events;
create policy cms_pages_editor_read on public.cms_pages for select to authenticated using (app_private.has_admin_permission('website_content.edit') or (status = 'draft' and created_by = auth.uid() and app_private.has_secretary_website_content_editor_assignment()));
create policy cms_news_posts_editor_read on public.cms_news_posts for select to authenticated using (app_private.has_admin_permission('website_content.edit') or (status = 'draft' and created_by = auth.uid() and app_private.has_secretary_website_content_editor_assignment()));
create policy public_events_editor_read on public.public_events for select to authenticated using (app_private.has_admin_permission('website_content.edit') or (status = 'draft' and created_by = auth.uid() and app_private.has_secretary_website_content_editor_assignment()));
create policy cms_pages_editor_insert on public.cms_pages for insert to authenticated with check (status = 'draft' and (app_private.has_admin_permission('website_content.edit') or app_private.has_secretary_website_content_editor_assignment()));
create policy cms_news_posts_editor_insert on public.cms_news_posts for insert to authenticated with check (status = 'draft' and (app_private.has_admin_permission('website_content.edit') or app_private.has_secretary_website_content_editor_assignment()));
create policy public_events_editor_insert on public.public_events for insert to authenticated with check (status = 'draft' and (app_private.has_admin_permission('website_content.edit') or app_private.has_secretary_website_content_editor_assignment()));
create policy cms_pages_editor_update on public.cms_pages for update to authenticated using (status = 'draft' and (app_private.has_admin_permission('website_content.edit') or (created_by = auth.uid() and app_private.has_secretary_website_content_editor_assignment()))) with check ((status = 'draft' and (app_private.has_admin_permission('website_content.edit') or (created_by = auth.uid() and app_private.has_secretary_website_content_editor_assignment()))) or (status = 'published' and app_private.has_admin_permission('website_content.publish')));
create policy cms_news_posts_editor_update on public.cms_news_posts for update to authenticated using (status = 'draft' and (app_private.has_admin_permission('website_content.edit') or (created_by = auth.uid() and app_private.has_secretary_website_content_editor_assignment()))) with check ((status = 'draft' and (app_private.has_admin_permission('website_content.edit') or (created_by = auth.uid() and app_private.has_secretary_website_content_editor_assignment()))) or (status = 'published' and app_private.has_admin_permission('website_content.publish')));
create policy public_events_editor_update on public.public_events for update to authenticated using (status = 'draft' and (app_private.has_admin_permission('website_content.edit') or (created_by = auth.uid() and app_private.has_secretary_website_content_editor_assignment()))) with check ((status = 'draft' and (app_private.has_admin_permission('website_content.edit') or (created_by = auth.uid() and app_private.has_secretary_website_content_editor_assignment()))) or (status = 'published' and app_private.has_admin_permission('website_content.publish')));
create policy cms_pages_secretary_delete_draft on public.cms_pages for delete to authenticated using (status = 'draft' and created_by = auth.uid() and app_private.has_secretary_website_content_editor_assignment());
create policy cms_news_posts_secretary_delete_draft on public.cms_news_posts for delete to authenticated using (status = 'draft' and created_by = auth.uid() and app_private.has_secretary_website_content_editor_assignment());
create policy public_events_secretary_delete_draft on public.public_events for delete to authenticated using (status = 'draft' and created_by = auth.uid() and app_private.has_secretary_website_content_editor_assignment());

create or replace function public.provision_portal_account(target_user_id uuid, target_role_code text, target_position_code text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare actor uuid := (select auth.uid()); selected_role_id uuid;
begin
  if not public.is_proprietor() then raise exception 'only the proprietor can provision accounts' using errcode = '42501'; end if;
  if target_role_code not in ('admin', 'teacher', 'parent', 'student', 'secretary') then raise exception 'invalid portal role' using errcode = '22023'; end if;
  if (target_role_code = 'admin') <> (target_position_code is not null) then raise exception 'administrator accounts require exactly one position' using errcode = '23514'; end if;
  if target_position_code is not null and target_position_code not in ('senior_administrator', 'headmistress') then raise exception 'only delegable administrator positions may be provisioned' using errcode = '42501'; end if;
  if not exists (select 1 from auth.users where id = target_user_id) then raise exception 'target must be an Auth identity' using errcode = '23503'; end if;
  if not exists (select 1 from public.profiles p where p.id = target_user_id and p.default_role_code is null and p.is_active) or exists (select 1 from public.user_roles where user_id = target_user_id) then raise exception 'target is already provisioned or inactive' using errcode = '23505'; end if;
  select id into selected_role_id from public.roles where code = target_role_code;
  update public.profiles set default_role_code = target_role_code where id = target_user_id;
  insert into public.user_roles(user_id, role_id) values (target_user_id, selected_role_id);
  if target_position_code is not null then insert into public.admin_position_assignments(user_id, position_code, assigned_by) values (target_user_id, target_position_code, actor); end if;
  insert into public.authorization_events(actor_user_id, subject_user_id, event_type) values (actor, target_user_id, 'account_created');
end;
$$;
