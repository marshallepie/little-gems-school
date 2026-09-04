-- Phase 4 CMS publication and ownership security tests. Run after the existing
-- authorization fixtures, which establish the proprietor profile used below.
begin;

set local role authenticated;
select set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-000000000004', true);

insert into public.cms_pages (id, slug, title, status, published_at, created_by) values
  ('42000000-0000-0000-0000-000000000001', 'phase4-visible-page', 'Visible page', 'published', now() - interval '1 minute', 'a0000000-0000-0000-0000-000000000001'),
  ('42000000-0000-0000-0000-000000000002', 'phase4-scheduled-page', 'Scheduled page', 'published', now() + interval '1 hour', 'a0000000-0000-0000-0000-000000000001');
insert into public.cms_news_posts (id, slug, title, status, published_at) values
  ('42000000-0000-0000-0000-000000000003', 'phase4-visible-news', 'Visible news', 'published', now() - interval '1 minute'),
  ('42000000-0000-0000-0000-000000000004', 'phase4-scheduled-news', 'Scheduled news', 'published', now() + interval '1 hour');
insert into public.public_events (id, slug, title, starts_at, ends_at, status, published_at) values
  ('42000000-0000-0000-0000-000000000005', 'phase4-visible-event', 'Visible event', now(), now() + interval '1 hour', 'published', now() - interval '1 minute'),
  ('42000000-0000-0000-0000-000000000006', 'phase4-scheduled-event', 'Scheduled event', now(), now() + interval '1 hour', 'published', now() + interval '1 hour');

do $$ declare immutable_error text; begin
  if exists (
    select 1 from public.cms_pages where id in ('42000000-0000-0000-0000-000000000001', '42000000-0000-0000-0000-000000000002') and created_by is distinct from auth.uid()
    union all
    select 1 from public.cms_news_posts where id in ('42000000-0000-0000-0000-000000000003', '42000000-0000-0000-0000-000000000004') and created_by is distinct from auth.uid()
    union all
    select 1 from public.public_events where id in ('42000000-0000-0000-0000-000000000005', '42000000-0000-0000-0000-000000000006') and created_by is distinct from auth.uid()
  ) then
    raise exception 'CMS insert did not assign created_by from auth.uid';
  end if;
  begin
    update public.cms_pages set created_by = 'a0000000-0000-0000-0000-000000000001' where id = '42000000-0000-0000-0000-000000000001';
    raise exception 'CMS created_by was mutable';
  exception when raise_exception then
    get stacked diagnostics immutable_error = message_text;
    if immutable_error <> 'created_by is immutable' then
      raise exception 'CMS created_by immutability check failed: %', immutable_error;
    end if;
  end;
end $$;

set local role anon;
select set_config('request.jwt.claim.sub', '', true);
do $$ begin
  if not exists (select 1 from public.cms_pages where id = '42000000-0000-0000-0000-000000000001')
     or exists (select 1 from public.cms_pages where id = '42000000-0000-0000-0000-000000000002') then
    raise exception 'CMS page publication time visibility failed';
  end if;
  if not exists (select 1 from public.cms_news_posts where id = '42000000-0000-0000-0000-000000000003')
     or exists (select 1 from public.cms_news_posts where id = '42000000-0000-0000-0000-000000000004') then
    raise exception 'CMS news publication time visibility failed';
  end if;
  if not exists (select 1 from public.public_events where id = '42000000-0000-0000-0000-000000000005')
     or exists (select 1 from public.public_events where id = '42000000-0000-0000-0000-000000000006') then
    raise exception 'CMS event publication time visibility failed';
  end if;
end $$;

rollback;
\echo 'PASS: Phase 4 CMS future publication and created_by protections'