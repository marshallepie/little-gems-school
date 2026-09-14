-- Secretary CMS operation-specific RLS and replacement-workflow checks.
-- Runs after administrative_authorization_cutover_gate.sql in db-behavioural-validate.sh.
begin;

-- Existing fixture b100...001 is proprietor and b100...002 is senior administrator.
-- Add two editor secretaries, an unassigned secretary, an unpositioned admin, and headmistress.
do $$
declare uid uuid; role_id uuid; r text; n int;
begin
  foreach uid in array array['d4000000-0000-0000-0000-000000000011'::uuid,'d4000000-0000-0000-0000-000000000012'::uuid,'d4000000-0000-0000-0000-000000000013'::uuid,'d4000000-0000-0000-0000-000000000014'::uuid,'d4000000-0000-0000-0000-000000000015'::uuid] loop
    insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
    values ('00000000-0000-0000-0000-000000000000',uid,'authenticated','authenticated',uid::text||'@example.test','$2a$10$012345678901234567890u012345678901234567890123456789012',now(),'{"provider":"email","providers":["email"]}','{}',now(),now());
  end loop;
  select id into role_id from public.roles where code='secretary';
  update public.profiles set default_role_code='secretary', profile_completed_at=now() where id in ('d4000000-0000-0000-0000-000000000011','d4000000-0000-0000-0000-000000000012','d4000000-0000-0000-0000-000000000013');
  insert into public.user_roles(user_id,role_id) select id,role_id from public.profiles where id in ('d4000000-0000-0000-0000-000000000011','d4000000-0000-0000-0000-000000000012','d4000000-0000-0000-0000-000000000013');
  select id into role_id from public.roles where code='admin';
  update public.profiles set default_role_code='admin', profile_completed_at=now() where id in ('d4000000-0000-0000-0000-000000000014','d4000000-0000-0000-0000-000000000015');
  insert into public.user_roles(user_id,role_id) values ('d4000000-0000-0000-0000-000000000014',role_id),('d4000000-0000-0000-0000-000000000015',role_id);
  insert into public.admin_position_assignments(user_id,position_code,assigned_by) values ('d4000000-0000-0000-0000-000000000015','headmistress','b1000000-0000-0000-0000-000000000001');
  insert into public.website_content_editor_assignments(user_id,assigned_by) values ('d4000000-0000-0000-0000-000000000011','b1000000-0000-0000-0000-000000000001'),('d4000000-0000-0000-0000-000000000012','b1000000-0000-0000-0000-000000000001');
end $$;

-- Secretary A creates one draft in every CMS table; Secretary B cannot read/update/delete it.
set local role authenticated;
select set_config('request.jwt.claim.sub','d4000000-0000-0000-0000-000000000011',true);
insert into public.cms_pages(slug,title,summary,body) values ('rls-page','page','private','body');
insert into public.cms_news_posts(slug,title,excerpt,body) values ('rls-news','news','private','body');
insert into public.public_events(slug,title,summary,details,starts_at,ends_at) values ('rls-event','event','private','details',now()+interval '1 day',now()+interval '2 days');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','d4000000-0000-0000-0000-000000000012',true);
do $$ declare t text; n int; begin
  foreach t in array array['cms_pages','cms_news_posts','public_events'] loop
    execute format('select count(*) from public.%I where slug = $1',t) into n using 'rls-'||case t when 'cms_pages' then 'page' when 'cms_news_posts' then 'news' else 'event' end;
    if n <> 0 then raise exception 'cross-secretary draft read was allowed for %',t; end if;
    execute format('update public.%I set title = title || '' x'' where slug = $1',t) using 'rls-'||case t when 'cms_pages' then 'page' when 'cms_news_posts' then 'news' else 'event' end; get diagnostics n = row_count;
    if n <> 0 then raise exception 'cross-secretary draft update was allowed for %',t; end if;
    execute format('delete from public.%I where slug = $1',t) using 'rls-'||case t when 'cms_pages' then 'page' when 'cms_news_posts' then 'news' else 'event' end; get diagnostics n = row_count;
    if n <> 0 then raise exception 'cross-secretary draft delete was allowed for %',t; end if;
  end loop;
end $$;
reset role;

-- No-assignment secretary and unpositioned admin cannot create or enumerate drafts.
set local role authenticated; select set_config('request.jwt.claim.sub','d4000000-0000-0000-0000-000000000013',true);
do $$ begin if exists(select 1 from public.cms_pages where status='draft') then raise exception 'unassigned secretary saw a draft'; end if; begin insert into public.cms_pages(slug,title) values ('denied-secretary','x'); raise exception 'unassigned secretary inserted'; exception when insufficient_privilege then null; end; end $$;
select set_config('request.jwt.claim.sub','d4000000-0000-0000-0000-000000000014',true);
do $$ begin if exists(select 1 from public.cms_pages where status='draft') then raise exception 'unpositioned admin saw a draft'; end if; begin insert into public.cms_pages(slug,title) values ('denied-admin','x'); raise exception 'unpositioned admin inserted'; exception when insufficient_privilege then null; end; end $$;
reset role;

-- Senior administrator publishes every draft. An assigned secretary cannot publish directly;
-- anonymous users can read published content only and cannot mutate any CMS table.
set local role authenticated; select set_config('request.jwt.claim.sub','b1000000-0000-0000-0000-000000000002',true);
update public.cms_pages set status='published' where slug='rls-page'; update public.cms_news_posts set status='published' where slug='rls-news'; update public.public_events set status='published' where slug='rls-event';
reset role;
set local role authenticated; select set_config('request.jwt.claim.sub','d4000000-0000-0000-0000-000000000011',true);
insert into public.cms_pages(slug,title) values ('secretary-publish-denied','private');
do $$ begin
  begin update public.cms_pages set status='published' where slug='secretary-publish-denied'; raise exception 'assigned secretary published a draft'; exception when insufficient_privilege then null; end;
  delete from public.cms_pages where status='published';
  if found then raise exception 'secretary deleted published content'; end if;
end $$;
reset role;
set local role anon; select set_config('request.jwt.claim.sub','',true);
do $$ begin
  if (select count(*) from public.cms_pages where status='published') <> 1 or (select count(*) from public.cms_news_posts where status='published') <> 1 or (select count(*) from public.public_events where status='published') <> 1 then raise exception 'anonymous published SELECT was not available'; end if;
  if exists(select 1 from public.cms_pages where status='draft') or exists(select 1 from public.cms_news_posts where status='draft') or exists(select 1 from public.public_events where status='draft') then raise exception 'anonymous reader saw draft'; end if;
  begin insert into public.cms_pages(slug,title) values ('anon-page-insert','x'); raise exception 'anonymous page INSERT was allowed'; exception when insufficient_privilege then null; end;
  begin insert into public.cms_news_posts(slug,title) values ('anon-news-insert','x'); raise exception 'anonymous news INSERT was allowed'; exception when insufficient_privilege then null; end;
  begin insert into public.public_events(slug,title,starts_at,ends_at) values ('anon-event-insert','x',now()+interval '1 day',now()+interval '2 days'); raise exception 'anonymous event INSERT was allowed'; exception when insufficient_privilege then null; end;
  begin update public.cms_pages set title='anonymous update' where slug='rls-page'; raise exception 'anonymous page UPDATE was allowed'; exception when insufficient_privilege then null; end;
  begin update public.cms_news_posts set title='anonymous update' where slug='rls-news'; raise exception 'anonymous news UPDATE was allowed'; exception when insufficient_privilege then null; end;
  begin update public.public_events set title='anonymous update' where slug='rls-event'; raise exception 'anonymous event UPDATE was allowed'; exception when insufficient_privilege then null; end;
  begin delete from public.cms_pages where slug='rls-page'; raise exception 'anonymous page DELETE was allowed'; exception when insufficient_privilege then null; end;
  begin delete from public.cms_news_posts where slug='rls-news'; raise exception 'anonymous news DELETE was allowed'; exception when insufficient_privilege then null; end;
  begin delete from public.public_events where slug='rls-event'; raise exception 'anonymous event DELETE was allowed'; exception when insufficient_privilege then null; end;
end $$;
reset role;
-- The psql harness connects as postgres; after RESET ROLE, inspect state as that
-- test owner/bypass role, not as the application service_role.
do $$ begin
  if exists(select 1 from public.cms_pages where slug='anon-page-insert') or exists(select 1 from public.cms_news_posts where slug='anon-news-insert') or exists(select 1 from public.public_events where slug='anon-event-insert') then raise exception 'anonymous INSERT changed CMS state'; end if;
  if (select title from public.cms_pages where slug='rls-page' and status='published') <> 'page' or (select title from public.cms_news_posts where slug='rls-news' and status='published') <> 'news' or (select title from public.public_events where slug='rls-event' and status='published') <> 'event' then raise exception 'anonymous UPDATE changed published CMS state'; end if;
  if not exists(select 1 from public.cms_pages where slug='rls-page' and status='published') or not exists(select 1 from public.cms_news_posts where slug='rls-news' and status='published') or not exists(select 1 from public.public_events where slug='rls-event' and status='published') then raise exception 'anonymous DELETE changed published CMS state'; end if;
end $$;
reset role;
set local role authenticated; select set_config('request.jwt.claim.sub','d4000000-0000-0000-0000-000000000015',true);
insert into public.cms_pages(slug,title) values ('head-page-draft','head');
insert into public.cms_news_posts(slug,title) values ('head-news-draft','head');
insert into public.public_events(slug,title,starts_at,ends_at) values ('head-event-draft','head',now()+interval '3 days',now()+interval '4 days');
do $$ begin
  begin update public.cms_pages set status='published' where slug='head-page-draft'; raise exception 'headmistress published page'; exception when insufficient_privilege then null; end;
  begin update public.cms_news_posts set status='published' where slug='head-news-draft'; raise exception 'headmistress published news'; exception when insufficient_privilege then null; end;
  begin update public.public_events set status='published' where slug='head-event-draft'; raise exception 'headmistress published event'; exception when insufficient_privilege then null; end;
end $$;
reset role;

-- Every CMS table rejects both a direct same-slug draft and a later draft slug
-- collision unless the draft identifies the exact active version. A valid page
-- replacement remains private to anonymous readers.
set local role authenticated; select set_config('request.jwt.claim.sub','d4000000-0000-0000-0000-000000000011',true);
do $$
declare t text; active_slug text; draft_slug text;
begin
  foreach t in array array['cms_pages','cms_news_posts','public_events'] loop
    active_slug := 'rls-' || case t when 'cms_pages' then 'page' when 'cms_news_posts' then 'news' else 'event' end;
    draft_slug := 'later-collision-' || case t when 'cms_pages' then 'page' when 'cms_news_posts' then 'news' else 'event' end;
    begin
      if t = 'public_events' then
        execute format('insert into public.%I(slug,title,starts_at,ends_at) values ($1,$2,now()+interval ''5 days'',now()+interval ''6 days'')', t) using active_slug, 'missing lineage';
      else
        execute format('insert into public.%I(slug,title) values ($1,$2)', t) using active_slug, 'missing lineage';
      end if;
      raise exception 'same-slug draft without lineage was allowed for %', t;
    exception when check_violation then null;
    end;
    if t = 'public_events' then
      execute format('insert into public.%I(slug,title,starts_at,ends_at) values ($1,$2,now()+interval ''5 days'',now()+interval ''6 days'')', t) using draft_slug, 'draft';
    else
      execute format('insert into public.%I(slug,title) values ($1,$2)', t) using draft_slug, 'draft';
    end if;
    begin
      execute format('update public.%I set slug = $1 where slug = $2', t) using active_slug, draft_slug;
      raise exception 'later slug collision without lineage was allowed for %', t;
    exception when check_violation then null;
    end;
  end loop;
end $$;
insert into public.cms_pages(slug,title,replaces_id) select slug,'replacement',id from public.cms_pages where slug='rls-page' and status='published';
reset role;
set local role anon; select set_config('request.jwt.claim.sub','',true);
do $$ begin
  if (select count(*) from public.cms_pages where slug='rls-page') <> 1 then raise exception 'anonymous reader saw replacement draft'; end if;
end $$;
reset role;
set local role authenticated; select set_config('request.jwt.claim.sub','b1000000-0000-0000-0000-000000000002',true);
update public.cms_pages set status='published' where slug='rls-page' and status='draft';
do $$ begin
  if (select count(*) from public.cms_pages where slug='rls-page' and status='published')<>1 or not exists(select 1 from public.cms_pages where slug='rls-page' and status='archived') then raise exception 'replacement did not retain one active and one archived version'; end if;
end $$;
reset role;
-- Test the trigger's immutability guard without the authenticated UPDATE policy
-- masking it; retain the senior administrator identity for the permission helper.
set local role service_role; select set_config('request.jwt.claim.sub','b1000000-0000-0000-0000-000000000002',true);
do $$ begin
  begin update public.cms_pages set title='mutated published record' where slug='rls-page' and status='published'; raise exception 'published content was mutable'; exception when insufficient_privilege then null; end;
end $$;
reset role;

-- Service-only grant/revoke retains only actor/subject/event type audit evidence.
set local role service_role; select set_config('request.jwt.claim.sub','b1000000-0000-0000-0000-000000000001',true);
do $$ begin
  if not exists (select 1 from public.website_content_editor_assignments where user_id='d4000000-0000-0000-0000-000000000011') then raise exception 'service role could not read editor assignment membership'; end if;
end $$;
select public.set_website_content_editor_from_server('d4000000-0000-0000-0000-000000000013','b1000000-0000-0000-0000-000000000001',true);
select public.set_website_content_editor_from_server('d4000000-0000-0000-0000-000000000013','b1000000-0000-0000-0000-000000000001',false);
do $$ begin if not exists(select 1 from public.authorization_events where actor_user_id='b1000000-0000-0000-0000-000000000001' and subject_user_id='d4000000-0000-0000-0000-000000000013' and event_type='website_content_editor_granted' and metadata='{}'::jsonb) or not exists(select 1 from public.authorization_events where actor_user_id='b1000000-0000-0000-0000-000000000001' and subject_user_id='d4000000-0000-0000-0000-000000000013' and event_type='website_content_editor_revoked' and metadata='{}'::jsonb) then raise exception 'editor grant/revoke audit missing or has metadata'; end if; end $$;
reset role;
rollback;
\echo 'PASS: secretary CMS operation-specific RLS and replacement workflow tests'
