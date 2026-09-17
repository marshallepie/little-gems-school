-- Self-contained communications/calendar command and RLS behaviour test.
-- Run through scripts/db-behavioural-validate.sh after the full migration chain.
-- Every fixture below is local to this transaction and is rolled back.
begin;

-- Fixture creation runs as the local postgres test owner, before switching to a
-- simulated authenticated request role. It does not depend on Phase 3 fixtures.
insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('00000000-0000-0000-0000-000000000000','a9000000-0000-0000-0000-000000000001','authenticated','authenticated','cc-unpositioned@example.test','$2a$10$012345678901234567890u012345678901234567890123456789012',now(),'{"provider":"email","providers":["email"]}','{}',now(),now()),
('00000000-0000-0000-0000-000000000000','a9000000-0000-0000-0000-000000000002','authenticated','authenticated','cc-manager@example.test','$2a$10$012345678901234567890u012345678901234567890123456789012',now(),'{"provider":"email","providers":["email"]}','{}',now(),now()),
('00000000-0000-0000-0000-000000000000','a9000000-0000-0000-0000-000000000003','authenticated','authenticated','cc-teacher@example.test','$2a$10$012345678901234567890u012345678901234567890123456789012',now(),'{"provider":"email","providers":["email"]}','{}',now(),now()),
('00000000-0000-0000-0000-000000000000','a9000000-0000-0000-0000-000000000004','authenticated','authenticated','cc-parent@example.test','$2a$10$012345678901234567890u012345678901234567890123456789012',now(),'{"provider":"email","providers":["email"]}','{}',now(),now()),
('00000000-0000-0000-0000-000000000000','a9000000-0000-0000-0000-000000000005','authenticated','authenticated','cc-student@example.test','$2a$10$012345678901234567890u012345678901234567890123456789012',now(),'{"provider":"email","providers":["email"]}','{}',now(),now()),
('00000000-0000-0000-0000-000000000000','a9000000-0000-0000-0000-000000000006','authenticated','authenticated','cc-unrelated-parent@example.test','$2a$10$012345678901234567890u012345678901234567890123456789012',now(),'{"provider":"email","providers":["email"]}','{}',now(),now());
update public.profiles p set default_role_code = v.role_code, profile_completed_at = now() from (values
('a9000000-0000-0000-0000-000000000001'::uuid,'admin'),('a9000000-0000-0000-0000-000000000002'::uuid,'admin'),('a9000000-0000-0000-0000-000000000003'::uuid,'teacher'),('a9000000-0000-0000-0000-000000000004'::uuid,'parent'),('a9000000-0000-0000-0000-000000000005'::uuid,'student'),('a9000000-0000-0000-0000-000000000006'::uuid,'parent')) v(user_id,role_code) where p.id = v.user_id;
insert into public.user_roles(user_id,role_id) select p.id,r.id from public.profiles p join public.roles r on r.code=p.default_role_code where p.id::text like 'a9000000-%';
insert into public.admin_position_assignments(user_id,position_code) values ('a9000000-0000-0000-0000-000000000002','headmistress');
insert into public.class_groups(id,academic_year_id,name,level)
select '49000000-0000-4000-8000-000000000001', id, 'Communications Test Class', 'Test' from public.academic_years where is_current;
insert into public.subjects(id,code,name) values ('39000000-0000-0000-0000-000000000001','CC-TEST','Communications Test');
insert into public.teachers(id,profile_id,staff_number,first_name,last_name) values ('b9000000-0000-0000-0000-000000000003','a9000000-0000-0000-0000-000000000003','CC-TEACH','Comms','Teacher');
insert into public.students(id,profile_id,admission_number,first_name,last_name) values ('c9000000-0000-0000-0000-000000000005','a9000000-0000-0000-0000-000000000005','CC-STUDENT','Comms','Student');
insert into public.guardians(id,profile_id,first_name,last_name,phone) values ('d9000000-0000-0000-0000-000000000004','a9000000-0000-0000-0000-000000000004','Comms','Parent','000'),('d9000000-0000-0000-0000-000000000006','a9000000-0000-0000-0000-000000000006','Unrelated','Parent','001');
insert into public.student_guardians(student_id,guardian_id,relationship,is_primary_contact) values ('c9000000-0000-0000-0000-000000000005','d9000000-0000-0000-0000-000000000004','Guardian',true);
insert into public.class_enrolments(student_id,class_group_id,starts_on,status) values ('c9000000-0000-0000-0000-000000000005','49000000-0000-4000-8000-000000000001',current_date - 1,'active');
insert into public.teacher_assignments(teacher_id,class_group_id,subject_id) values ('b9000000-0000-0000-0000-000000000003','49000000-0000-4000-8000-000000000001','39000000-0000-0000-0000-000000000001');

set local role authenticated;
select set_config('request.jwt.claim.sub','a9000000-0000-0000-0000-000000000001',true);
do $$ begin
  if app_private.has_admin_permission('communications.manage') or app_private.has_admin_permission('calendar.manage') then raise exception 'unpositioned admin gained command permission'; end if;
  begin perform public.manage_internal_announcement(null,'draft','Denied','x','[{"target_kind":"school","role_code":null,"class_group_id":null}]'); raise exception 'unpositioned announcement command succeeded'; exception when insufficient_privilege then null; end;
  begin insert into public.announcements(title,body,status,created_by) values ('Direct denied','x','draft',auth.uid()); raise exception 'unpositioned direct draft insert succeeded'; exception when insufficient_privilege then null; end;
end $$;

select set_config('request.jwt.claim.sub','a9000000-0000-0000-0000-000000000002',true);
do $$ declare a uuid; e uuid; legacy_class uuid; class_only uuid; parent_only uuid; old_title text; old_targets integer; begin
  if not app_private.has_admin_permission('communications.manage') or not app_private.has_admin_permission('calendar.manage') then raise exception 'manager lacks command permission'; end if;
  -- The seeded current class uses a valid PostgreSQL UUID with a version-0 nibble.
  legacy_class := public.manage_internal_announcement(null,'draft','Legacy UUID class','x','[{"target_kind":"class","role_code":null,"class_group_id":"40000000-0000-0000-0000-000000000001"}]');
  if legacy_class is null then raise exception 'legacy current-class UUID command returned no ID'; end if;
  a := public.manage_internal_announcement(null,'draft','School, teacher, and class','Draft','[{"target_kind":"school","role_code":null,"class_group_id":null},{"target_kind":"role","role_code":"teacher","class_group_id":null},{"target_kind":"class","role_code":null,"class_group_id":"49000000-0000-4000-8000-000000000001"}]');
  begin perform public.manage_internal_announcement(a,'publish','School, teacher, and class','Draft','[]'); raise exception 'zero-target publication succeeded'; exception when check_violation then null; end;
  select title, (select count(*) from public.announcement_targets where announcement_id=a) into old_title, old_targets from public.announcements where id=a;
  begin perform public.manage_internal_announcement(a,'draft','Should rollback','Changed','[{"target_kind":"class","role_code":null,"class_group_id":"49000000-0000-4000-8000-000000000099"}]'); raise exception 'stale target replacement succeeded'; exception when check_violation then null; end;
  if (select title from public.announcements where id=a) <> old_title or (select count(*) from public.announcement_targets where announcement_id=a) <> old_targets then raise exception 'failed target replacement was not atomic'; end if;
  perform public.manage_internal_announcement(a,'publish','School, teacher, and class','Draft','[{"target_kind":"school","role_code":null,"class_group_id":null},{"target_kind":"role","role_code":"teacher","class_group_id":null},{"target_kind":"class","role_code":null,"class_group_id":"49000000-0000-4000-8000-000000000001"}]');
  class_only := public.manage_internal_announcement(null,'draft','Class only','x','[{"target_kind":"class","role_code":null,"class_group_id":"49000000-0000-4000-8000-000000000001"}]');
  perform public.manage_internal_announcement(class_only,'publish','Class only','x','[{"target_kind":"class","role_code":null,"class_group_id":"49000000-0000-4000-8000-000000000001"}]');
  parent_only := public.manage_internal_announcement(null,'draft','Parents only','x','[{"target_kind":"role","role_code":"parent","class_group_id":null}]');
  perform public.manage_internal_announcement(parent_only,'publish','Parents only','x','[{"target_kind":"role","role_code":"parent","class_group_id":null}]');
  e := public.manage_private_event(null,'draft','Private event','x','2028-02-29 09:00:00+00','2028-02-29 10:00:00+00','[{"target_kind":"school","role_code":null,"class_group_id":null}]');
  perform public.manage_private_event(e,'publish','Private event','x','2028-02-29 09:00:00+00','2028-02-29 10:00:00+00','[{"target_kind":"school","role_code":null,"class_group_id":null}]');
  begin insert into public.operational_events(actor_user_id,entity_type,entity_id,event_type) values (auth.uid(),'announcement',a,'forged'); raise exception 'manager directly wrote audit event'; exception when insufficient_privilege then null; end;
  if not exists(select 1 from public.operational_events where entity_id=a and actor_user_id=auth.uid() and event_type='created') or not exists(select 1 from public.operational_events where entity_id=a and actor_user_id=auth.uid() and event_type='audience_replaced') or not exists(select 1 from public.operational_events where entity_id=a and actor_user_id=auth.uid() and event_type='status_changed') then raise exception 'announcement audit actor or events missing'; end if;
  if not exists(select 1 from public.operational_events where entity_id=e and actor_user_id=auth.uid() and event_type='status_changed') then raise exception 'event audit actor missing'; end if;
  perform public.manage_internal_announcement(a,'archive','ignored','ignored','[]');
  begin perform public.manage_internal_announcement(a,'draft','reopen','x','[{"target_kind":"school","role_code":null,"class_group_id":null}]'); raise exception 'archived announcement reopened'; exception when check_violation then null; end;
  perform public.manage_private_event(e,'cancel','ignored','ignored','2028-02-29 09:00:00+00','2028-02-29 10:00:00+00','[]');
  begin perform public.manage_private_event(e,'publish','reopen','x','2028-02-29 09:00:00+00','2028-02-29 10:00:00+00','[{"target_kind":"school","role_code":null,"class_group_id":null}]'); raise exception 'cancelled event republished'; exception when check_violation then null; end;
end $$;

-- Matching teacher has school/class content but cannot enumerate or change targets/audit.
select set_config('request.jwt.claim.sub','a9000000-0000-0000-0000-000000000003',true);
do $$ begin
  if not exists(select 1 from public.announcements where title='Class only') then raise exception 'teacher lost class audience'; end if;
  if exists(select 1 from public.announcements where title='Parents only') then raise exception 'teacher read parent-role audience'; end if;
  if exists(select 1 from public.announcement_targets) then raise exception 'teacher enumerated announcement targets'; end if;
  if exists(select 1 from public.event_targets) then raise exception 'teacher enumerated event targets'; end if;
  if exists(select 1 from public.operational_events where entity_type='announcement') then raise exception 'teacher enumerated protected audit'; end if;
  if exists (
    select 1
    from (values
      ('public.announcements', 'INSERT'), ('public.announcements', 'UPDATE'), ('public.announcements', 'DELETE'),
      ('public.announcement_targets', 'INSERT'), ('public.announcement_targets', 'UPDATE'), ('public.announcement_targets', 'DELETE'),
      ('public.events', 'INSERT'), ('public.events', 'UPDATE'), ('public.events', 'DELETE'),
      ('public.event_targets', 'INSERT'), ('public.event_targets', 'UPDATE'), ('public.event_targets', 'DELETE')
    ) as direct_dml(table_name, privilege)
    where has_table_privilege('authenticated', table_name, privilege)
  ) then
    raise exception 'authenticated direct communications/calendar mutation privilege remains';
  end if;
  begin insert into public.announcement_targets(announcement_id,target_kind) values ('00000000-0000-0000-0000-000000000001','school'); raise exception 'teacher changed target'; exception when insufficient_privilege then null; end;
end $$;
-- Linked parent and enrolled student receive their matching role/class feeds but
-- cannot read the target metadata used by the SECURITY DEFINER feed predicates.
select set_config('request.jwt.claim.sub','a9000000-0000-0000-0000-000000000004',true);
do $$ begin
  if not exists(select 1 from public.announcements where title='Class only') or not exists(select 1 from public.announcements where title='Parents only') then raise exception 'linked parent lost matching feed'; end if;
  if exists(select 1 from public.announcement_targets) then raise exception 'parent enumerated announcement targets'; end if;
  if exists(select 1 from public.event_targets) then raise exception 'parent enumerated event targets'; end if;
end $$;
select set_config('request.jwt.claim.sub','a9000000-0000-0000-0000-000000000005',true);
do $$ begin
  if not exists(select 1 from public.announcements where title='Class only') then raise exception 'student lost class feed'; end if;
  if exists(select 1 from public.announcement_targets) then raise exception 'student enumerated announcement targets'; end if;
  if exists(select 1 from public.event_targets) then raise exception 'student enumerated event targets'; end if;
end $$;
-- An unrelated parent gets its role-wide message but not the class-only record.
select set_config('request.jwt.claim.sub','a9000000-0000-0000-0000-000000000006',true);
do $$ begin if exists(select 1 from public.announcements where title='Class only') or not exists(select 1 from public.announcements where title='Parents only') then raise exception 'unrelated parent crossed class boundary'; end if; end $$;
-- Remove only this fixture manager's calendar grant after it has completed both
-- commands; RLS must still expose announcement audit but hide event audit.
reset role;
delete from public.admin_position_permissions where position_code='headmistress' and permission_code='calendar.manage';
set local role authenticated;
select set_config('request.jwt.claim.sub','a9000000-0000-0000-0000-000000000002',true);
do $$ begin
  if not exists(select 1 from public.operational_events where entity_type='announcement') then raise exception 'communications manager lost matching audit scope'; end if;
  if exists(select 1 from public.operational_events where entity_type='event') then raise exception 'communications manager read calendar audit without calendar permission'; end if;
end $$;
reset role;
rollback;
\echo 'PASS: self-contained communications/calendar command, lifecycle, audience, and audit behaviour'
