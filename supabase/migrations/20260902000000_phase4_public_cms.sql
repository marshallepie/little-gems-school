-- Phase 4 public CMS. These tables are distinct from Phase 3's private events;
-- no existing Phase 3 schema, constraints, or policies are altered.
insert into public.admin_permissions (code, name) values
  ('website.manage', 'Manage public website content')
on conflict (code) do update set name = excluded.name;

insert into public.admin_position_permissions (position_code, permission_code) values
  ('proprietor_super_admin', 'website.manage'),
  ('senior_administrator', 'website.manage'),
  ('headmistress', 'website.manage')
on conflict do nothing;

create table public.cms_pages (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  title text not null check (length(btrim(title)) between 1 and 160),
  summary text not null default '' check (length(summary) <= 500),
  body text not null default '' check (length(body) <= 20000),
  status text not null default 'draft' check (status in ('draft', 'published')),
  published_at timestamptz,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((status = 'draft' and published_at is null) or (status = 'published' and published_at is not null))
);

create table public.cms_news_posts (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  title text not null check (length(btrim(title)) between 1 and 160),
  excerpt text not null default '' check (length(excerpt) <= 500),
  body text not null default '' check (length(body) <= 20000),
  status text not null default 'draft' check (status in ('draft', 'published')),
  published_at timestamptz,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((status = 'draft' and published_at is null) or (status = 'published' and published_at is not null))
);

create table public.public_events (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  title text not null check (length(btrim(title)) between 1 and 160),
  summary text not null default '' check (length(summary) <= 500),
  details text not null default '' check (length(details) <= 20000),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status text not null default 'draft' check (status in ('draft', 'published')),
  published_at timestamptz,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at > starts_at),
  check ((status = 'draft' and published_at is null) or (status = 'published' and published_at is not null))
);

create function app_private.phase4_cms_updated_at() returns trigger language plpgsql security definer set search_path = '' as $$
begin new.updated_at = now(); return new; end;
$$;
revoke all on function app_private.phase4_cms_updated_at() from public, anon, authenticated;
create function app_private.phase4_cms_created_by() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    new.created_by = auth.uid();
  elsif new.created_by is distinct from old.created_by then
    raise exception 'created_by is immutable';
  end if;
  return new;
end;
$$;
revoke all on function app_private.phase4_cms_created_by() from public, anon, authenticated;
create trigger cms_pages_updated before update on public.cms_pages for each row execute procedure app_private.phase4_cms_updated_at();
create trigger cms_news_posts_updated before update on public.cms_news_posts for each row execute procedure app_private.phase4_cms_updated_at();
create trigger public_events_updated before update on public.public_events for each row execute procedure app_private.phase4_cms_updated_at();
create trigger cms_pages_created_by before insert or update on public.cms_pages for each row execute procedure app_private.phase4_cms_created_by();
create trigger cms_news_posts_created_by before insert or update on public.cms_news_posts for each row execute procedure app_private.phase4_cms_created_by();
create trigger public_events_created_by before insert or update on public.public_events for each row execute procedure app_private.phase4_cms_created_by();

create index cms_news_posts_public_idx on public.cms_news_posts(published_at desc) where status = 'published';
create index public_events_public_idx on public.public_events(starts_at) where status = 'published';

grant select on public.cms_pages, public.cms_news_posts, public.public_events to anon, authenticated;
grant insert, update, delete on public.cms_pages, public.cms_news_posts, public.public_events to authenticated;
alter table public.cms_pages enable row level security;
alter table public.cms_news_posts enable row level security;
alter table public.public_events enable row level security;

create policy cms_pages_published_read on public.cms_pages for select to anon, authenticated using (status = 'published' and published_at <= now());
create policy cms_pages_admin_write on public.cms_pages for all to authenticated using (app_private.has_admin_permission('website.manage')) with check (app_private.has_admin_permission('website.manage'));
create policy cms_news_posts_published_read on public.cms_news_posts for select to anon, authenticated using (status = 'published' and published_at <= now());
create policy cms_news_posts_admin_write on public.cms_news_posts for all to authenticated using (app_private.has_admin_permission('website.manage')) with check (app_private.has_admin_permission('website.manage'));
create policy public_events_published_read on public.public_events for select to anon, authenticated using (status = 'published' and published_at <= now());
create policy public_events_admin_write on public.public_events for all to authenticated using (app_private.has_admin_permission('website.manage')) with check (app_private.has_admin_permission('website.manage'));
