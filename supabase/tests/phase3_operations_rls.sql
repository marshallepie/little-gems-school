-- Phase 3 Batch 1 deterministic security tests. Run on a disposable local stack
-- after the authorization cutover fixture has established its required proprietor.
begin;
insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('00000000-0000-0000-0000-000000000000','a0000000-0000-0000-0000-000000000001','authenticated','authenticated','p3-unpositioned@example.test','$2a$10$012345678901234567890u012345678901234567890123456789012',now(),'{"provider":"email","providers":["email"]}','{}',now(),now()),
('00000000-0000-0000-0000-000000000000','a0000000-0000-0000-0000-000000000002','authenticated','authenticated','p3-head@example.test','$2a$10$012345678901234567890u012345678901234567890123456789012',now(),'{"provider":"email","providers":["email"]}','{}',now(),now()),
('00000000-0000-0000-0000-000000000000','a0000000-0000-0000-0000-000000000003','authenticated','authenticated','p3-senior@example.test','$2a$10$012345678901234567890u012345678901234567890123456789012',now(),'{"provider":"email","providers":["email"]}','{}',now(),now()),
('00000000-0000-0000-0000-000000000000','a0000000-0000-0000-0000-000000000004','authenticated','authenticated','p3-proprietor@example.test','$2a$10$012345678901234567890u012345678901234567890123456789012',now(),'{"provider":"email","providers":["email"]}','{}',now(),now()),
('00000000-0000-0000-0000-000000000000','a0000000-0000-0000-0000-000000000005','authenticated','authenticated','p3-teacher-a@example.test','$2a$10$012345678901234567890u012345678901234567890123456789012',now(),'{"provider":"email","providers":["email"]}','{}',now(),now()),
('00000000-0000-0000-0000-000000000000','a0000000-0000-0000-0000-000000000006','authenticated','authenticated','p3-teacher-b@example.test','$2a$10$012345678901234567890u012345678901234567890123456789012',now(),'{"provider":"email","providers":["email"]}','{}',now(),now()),
('00000000-0000-0000-0000-000000000000','a0000000-0000-0000-0000-000000000007','authenticated','authenticated','p3-parent-a@example.test','$2a$10$012345678901234567890u012345678901234567890123456789012',now(),'{"provider":"email","providers":["email"]}','{}',now(),now()),
('00000000-0000-0000-0000-000000000000','a0000000-0000-0000-0000-000000000008','authenticated','authenticated','p3-student-a@example.test','$2a$10$012345678901234567890u012345678901234567890123456789012',now(),'{"provider":"email","providers":["email"]}','{}',now(),now()),
('00000000-0000-0000-0000-000000000000','a0000000-0000-0000-0000-000000000009','authenticated','authenticated','p3-parent-b@example.test','$2a$10$012345678901234567890u012345678901234567890123456789012',now(),'{"provider":"email","providers":["email"]}','{}',now(),now()),
('00000000-0000-0000-0000-000000000000','a0000000-0000-0000-0000-000000000010','authenticated','authenticated','p3-student-b@example.test','$2a$10$012345678901234567890u012345678901234567890123456789012',now(),'{"provider":"email","providers":["email"]}','{}',now(),now());
update public.profiles p set default_role_code=v.role_code from (values
('a0000000-0000-0000-0000-000000000001'::uuid,'admin'),('a0000000-0000-0000-0000-000000000002'::uuid,'admin'),('a0000000-0000-0000-0000-000000000003'::uuid,'admin'),('a0000000-0000-0000-0000-000000000004'::uuid,'admin'),('a0000000-0000-0000-0000-000000000005'::uuid,'teacher'),('a0000000-0000-0000-0000-000000000006'::uuid,'teacher'),('a0000000-0000-0000-0000-000000000007'::uuid,'parent'),('a0000000-0000-0000-0000-000000000008'::uuid,'student'),('a0000000-0000-0000-0000-000000000009'::uuid,'parent'),('a0000000-0000-0000-0000-000000000010'::uuid,'student')) v(user_id,role_code) where p.id=v.user_id;
insert into public.user_roles(user_id,role_id) select p.id,r.id from public.profiles p join public.roles r on r.code=p.default_role_code where p.id::text like 'a0000000-%';
insert into public.admin_position_assignments(user_id,position_code) values ('a0000000-0000-0000-0000-000000000002','headmistress'),('a0000000-0000-0000-0000-000000000003','senior_administrator'),('a0000000-0000-0000-0000-000000000004','proprietor_super_admin');
insert into public.teachers(id,profile_id,staff_number,first_name,last_name) values ('b0000000-0000-0000-0000-000000000005','a0000000-0000-0000-0000-000000000005','P3-TA','Teacher','A'),('b0000000-0000-0000-0000-000000000006','a0000000-0000-0000-0000-000000000006','P3-TB','Teacher','B');
insert into public.students(id,profile_id,admission_number,first_name,last_name) values ('c0000000-0000-0000-0000-000000000008','a0000000-0000-0000-0000-000000000008','P3-SA','Student','A'),('c0000000-0000-0000-0000-000000000010','a0000000-0000-0000-0000-000000000010','P3-SB','Student','B');
insert into public.guardians(id,profile_id,first_name,last_name,phone) values ('d0000000-0000-0000-0000-000000000007','a0000000-0000-0000-0000-000000000007','Parent','A','000'),('d0000000-0000-0000-0000-000000000009','a0000000-0000-0000-0000-000000000009','Parent','B','000');
insert into public.student_guardians values ('c0000000-0000-0000-0000-000000000008','d0000000-0000-0000-0000-000000000007','Guardian',true),('c0000000-0000-0000-0000-000000000010','d0000000-0000-0000-0000-000000000009','Guardian',true);
insert into public.class_enrolments(id,student_id,class_group_id,starts_on,status) values ('e0000000-0000-0000-0000-000000000008','c0000000-0000-0000-0000-000000000008','40000000-0000-0000-0000-000000000001','2026-09-01','active'),('e0000000-0000-0000-0000-000000000010','c0000000-0000-0000-0000-000000000010','40000000-0000-0000-0000-000000000002','2026-09-01','active');
insert into public.teacher_assignments(id,teacher_id,class_group_id,subject_id,term_id) values
('f0000000-0000-0000-0000-000000000005','b0000000-0000-0000-0000-000000000005','40000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001'),
('f0000000-0000-0000-0000-000000000006','b0000000-0000-0000-0000-000000000006','40000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001'),
-- Teacher A has a foreign assignment in B, but it cannot authorize B's persisted register.
('f0000000-0000-0000-0000-000000000015','b0000000-0000-0000-0000-000000000005','40000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001'),
-- Teacher B independently teaches the exact same class/subject/term tuple as A.
('f0000000-0000-0000-0000-000000000016','b0000000-0000-0000-0000-000000000006','40000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001');
insert into public.academic_years(id,name,starts_on,ends_on) values ('10000000-0000-0000-0000-000000000099','2025/2026','2025-09-01','2026-07-31',false);
insert into public.terms(id,academic_year_id,name,starts_on,ends_on) values ('20000000-0000-0000-0000-000000000099','10000000-0000-0000-0000-000000000099','Term 1','2025-09-01','2025-12-18');
insert into public.class_groups(id,academic_year_id,name,level) values ('40000000-0000-0000-0000-000000000099','10000000-0000-0000-0000-000000000099','Historical A','Foundation');
insert into public.teacher_assignments(id,teacher_id,class_group_id,subject_id,term_id) values ('f0000000-0000-0000-0000-000000000099','b0000000-0000-0000-0000-000000000005','40000000-0000-0000-0000-000000000099','30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000099');

insert into public.timetable_entries(id,term_id,class_group_id,subject_id,teacher_assignment_id,weekday,session_number,starts_at,ends_at) values
('91000000-0000-0000-0000-000000000005','20000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','f0000000-0000-0000-0000-000000000005',2,1,'08:00','08:45'),
('91000000-0000-0000-0000-000000000006','20000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001','f0000000-0000-0000-0000-000000000006',3,1,'08:00','08:45'),
('91000000-0000-0000-0000-000000000016','20000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002','f0000000-0000-0000-0000-000000000015',3,2,'09:00','09:45');
insert into public.assessments(id,teacher_assignment_id,term_id,title,assessment_date,maximum_score,status,created_by) values ('12000000-0000-0000-0000-000000000001','f0000000-0000-0000-0000-000000000005','20000000-0000-0000-0000-000000000001','Check','2026-09-03',10,'draft','a0000000-0000-0000-0000-000000000005');
update public.assessments set status='published', published_at=now() where id='12000000-0000-0000-0000-000000000001';
insert into public.assessment_results(assessment_id,student_id,score) values ('12000000-0000-0000-0000-000000000001','c0000000-0000-0000-0000-000000000008',8);
insert into public.attendance_sessions(id,class_group_id,teacher_assignment_id,attendance_date,timetable_entry_id,status,submitted_at,student_visible) values
('13000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','f0000000-0000-0000-0000-000000000005','2026-09-01','91000000-0000-0000-0000-000000000005','draft',null,false),
('13000000-0000-0000-0000-000000000002','40000000-0000-0000-0000-000000000002','f0000000-0000-0000-0000-000000000006','2026-09-02','91000000-0000-0000-0000-000000000006','draft',null,false),
('13000000-0000-0000-0000-000000000003','40000000-0000-0000-0000-000000000001','f0000000-0000-0000-0000-000000000005','2026-09-03',null,'draft',null,false);
insert into public.attendance_records(attendance_session_id,student_id,status) values ('13000000-0000-0000-0000-000000000001','c0000000-0000-0000-0000-000000000008','present'),('13000000-0000-0000-0000-000000000002','c0000000-0000-0000-0000-000000000010','present');
insert into public.documents(id,title,file_name,mime_type,byte_size,status,created_by) values ('14000000-0000-0000-0000-000000000001','All-target document','all.pdf','application/pdf',10,'draft',null),('14000000-0000-0000-0000-000000000002','A-only document','a.pdf','application/pdf',10,'draft',null),('14000000-0000-0000-0000-000000000003','Creator-only document','creator.pdf','application/pdf',10,'draft','a0000000-0000-0000-0000-000000000009');
update public.documents set status='available',available_at=now() where id in ('14000000-0000-0000-0000-000000000001','14000000-0000-0000-0000-000000000002','14000000-0000-0000-0000-000000000003');

-- Parallel same-tuple teachers own distinct drafts. The third A draft is the
-- assignment that the review workflow later publishes to the family audience.
insert into public.assignments(id,teacher_assignment_id,term_id,title,instructions,assigned_on,status,created_by) values
('11000000-0000-0000-0000-000000000001','f0000000-0000-0000-0000-000000000005','20000000-0000-0000-0000-000000000001','A private draft','A draft','2026-09-02','draft','a0000000-0000-0000-0000-000000000005'),
('11000000-0000-0000-0000-000000000002','f0000000-0000-0000-0000-000000000016','20000000-0000-0000-0000-000000000001','B private draft','B draft','2026-09-02','draft','a0000000-0000-0000-0000-000000000006'),
('11000000-0000-0000-0000-000000000003','f0000000-0000-0000-0000-000000000005','20000000-0000-0000-0000-000000000001','Family visibility draft','Publish only after review','2026-09-03','draft','a0000000-0000-0000-0000-000000000005');
insert into public.assignment_documents(assignment_id,document_id) values ('11000000-0000-0000-0000-000000000001','14000000-0000-0000-0000-000000000001'),('11000000-0000-0000-0000-000000000002','14000000-0000-0000-0000-000000000002');
insert into public.assessments(id,teacher_assignment_id,term_id,title,assessment_date,maximum_score,status,created_by) values
('12000000-0000-0000-0000-000000000002','f0000000-0000-0000-0000-000000000005','20000000-0000-0000-0000-000000000001','A private assessment','2026-09-04',10,'draft','a0000000-0000-0000-0000-000000000005'),
('12000000-0000-0000-0000-000000000003','f0000000-0000-0000-0000-000000000016','20000000-0000-0000-0000-000000000001','B private assessment','2026-09-04',10,'draft','a0000000-0000-0000-0000-000000000006');
insert into public.assessment_results(assessment_id,student_id,score,recorded_by) values
('12000000-0000-0000-0000-000000000002','c0000000-0000-0000-0000-000000000008',7,'a0000000-0000-0000-0000-000000000005'),
('12000000-0000-0000-0000-000000000003','c0000000-0000-0000-0000-000000000008',9,'a0000000-0000-0000-0000-000000000006');


-- School, role, and class targets all accept their valid normalized NULL combinations.
insert into public.announcements(id,title,body,status,published_at) values ('15000000-0000-0000-0000-000000000001','All targets','x','published',now()),('15000000-0000-0000-0000-000000000002','A only','x','published',now());
insert into public.announcement_targets values
('15000000-0000-0000-0000-000000000001','school',null,null),('15000000-0000-0000-0000-000000000001','role','parent',null),('15000000-0000-0000-0000-000000000001','class',null,'40000000-0000-0000-0000-000000000001'),
('15000000-0000-0000-0000-000000000002','class',null,'40000000-0000-0000-0000-000000000001');
insert into public.events(id,title,starts_at,ends_at,status,published_at) values ('16000000-0000-0000-0000-000000000001','All targets',now(),now()+interval '1 hour','published',now()),('16000000-0000-0000-0000-000000000002','A only',now(),now()+interval '1 hour','published',now());
insert into public.event_targets values
('16000000-0000-0000-0000-000000000001','school',null,null),('16000000-0000-0000-0000-000000000001','role','parent',null),('16000000-0000-0000-0000-000000000001','class',null,'40000000-0000-0000-0000-000000000001'),
('16000000-0000-0000-0000-000000000002','class',null,'40000000-0000-0000-0000-000000000001');
insert into public.document_targets values
('14000000-0000-0000-0000-000000000001','school',null,null),('14000000-0000-0000-0000-000000000001','role','parent',null),('14000000-0000-0000-0000-000000000001','class',null,'40000000-0000-0000-0000-000000000001'),
('14000000-0000-0000-0000-000000000002','class',null,'40000000-0000-0000-0000-000000000001');

set local role authenticated;
select set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000001',true);
do $$ begin if app_private.has_admin_permission('results.release') or exists(select 1 from public.timetable_entries) then raise exception 'unpositioned admin gained Phase 3 access'; end if; end $$;
select set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000002',true);
do $$ begin if app_private.has_admin_permission('results.release') then raise exception 'headmistress can release'; end if; begin update public.assessments set status='released',released_at=now() where id='12000000-0000-0000-0000-000000000001'; raise exception 'headmistress release attempt unexpectedly succeeded'; exception when insufficient_privilege then null; end; if exists(select 1 from public.assessments where id='12000000-0000-0000-0000-000000000001' and status='released') then raise exception 'headmistress released results'; end if; end $$;
select set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000003',true);
update public.assessments set status='released',released_at=now() where id='12000000-0000-0000-0000-000000000001';
do $$ begin if not app_private.has_admin_permission('results.release') then raise exception 'senior cannot release'; end if; end $$;
select set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000004',true);
do $$ begin if not app_private.has_admin_permission('results.release') then raise exception 'proprietor cannot release'; end if; end $$;
select set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000005',true);
do $$ declare changed integer; identity_sqlstate text; begin
  -- Exact-id ownership keeps concurrent same-tuple teacher B out of every A draft.
  if not exists(select 1 from public.assignments where id='11000000-0000-0000-0000-000000000001') then raise exception 'teacher A lost own assignment draft'; end if;
  if exists(select 1 from public.assignments where id='11000000-0000-0000-0000-000000000002') then raise exception 'teacher A read teacher B same-tuple assignment draft'; end if;
  update public.assignments set title='A private draft edited' where id='11000000-0000-0000-0000-000000000001';
  if not exists(select 1 from public.assignments where id='11000000-0000-0000-0000-000000000001' and title='A private draft edited') then raise exception 'teacher A could not edit own assignment draft'; end if;
  begin update public.assignments set status='published', published_at=now() where id='11000000-0000-0000-0000-000000000001'; raise exception 'teacher A published an assignment'; exception when insufficient_privilege then null; end;
  if not exists(select 1 from public.assignments where id='11000000-0000-0000-0000-000000000001' and status='draft') then raise exception 'teacher assignment publication changed draft'; end if;
  if exists(select 1 from public.assessments where id='12000000-0000-0000-0000-000000000003') or exists(select 1 from public.assessment_results where assessment_id='12000000-0000-0000-0000-000000000003') or exists(select 1 from public.assignment_documents where assignment_id='11000000-0000-0000-0000-000000000002') then raise exception 'teacher A read teacher B same-tuple assessment, result, or document'; end if;
  update public.assessments set title='A private assessment edited' where id='12000000-0000-0000-0000-000000000002';
  if not exists(select 1 from public.assessments where id='12000000-0000-0000-0000-000000000002' and title='A private assessment edited') then raise exception 'teacher A could not edit own assessment draft'; end if;
  if not exists(select 1 from public.assessment_results where assessment_id='12000000-0000-0000-0000-000000000002') or not exists(select 1 from public.assignment_documents where assignment_id='11000000-0000-0000-0000-000000000001') then raise exception 'teacher A lost own result or assignment document draft access'; end if;
  update public.assessments set title='peer edit' where id='12000000-0000-0000-0000-000000000003'; get diagnostics changed = row_count;
  if changed <> 0 then raise exception 'teacher A changed teacher B same-tuple assessment'; end if;
  if exists(select 1 from public.attendance_sessions where id='13000000-0000-0000-0000-000000000002') then raise exception 'teacher A accessed teacher B register through foreign assignment'; end if;
  if not exists(select 1 from public.attendance_sessions where id='13000000-0000-0000-0000-000000000001') then raise exception 'teacher A lost owned register'; end if;
  begin
    update public.attendance_sessions
    set teacher_assignment_id='f0000000-0000-0000-0000-000000000015',
        class_group_id='40000000-0000-0000-0000-000000000002',
        attendance_date='2026-09-02',
        session_number=2,
        timetable_entry_id='91000000-0000-0000-0000-000000000016'
    where id='13000000-0000-0000-0000-000000000001';
    raise exception 'teacher A rewrote owned draft register identity';
  exception when insufficient_privilege then
    get stacked diagnostics identity_sqlstate = returned_sqlstate;
    if identity_sqlstate <> '42501' then raise exception 'teacher identity freeze returned SQLSTATE %, expected 42501', identity_sqlstate; end if;
  end;
  if not exists(select 1 from public.attendance_sessions where id='13000000-0000-0000-0000-000000000001' and teacher_assignment_id='f0000000-0000-0000-0000-000000000005' and class_group_id='40000000-0000-0000-0000-000000000001' and attendance_date='2026-09-01' and session_number=1 and timetable_entry_id='91000000-0000-0000-0000-000000000005') then raise exception 'teacher identity freeze changed owned draft'; end if;
  update public.attendance_sessions set updated_by = null where id='13000000-0000-0000-0000-000000000003';
  if not exists(select 1 from public.attendance_sessions where id='13000000-0000-0000-0000-000000000003' and status='draft' and not student_visible) then raise exception 'teacher A could not retain owned draft'; end if;
  begin update public.attendance_sessions set student_visible=true where id='13000000-0000-0000-0000-000000000003'; raise exception 'teacher A made draft student-visible'; exception when insufficient_privilege then null; end;
  if not exists(select 1 from public.attendance_sessions where id='13000000-0000-0000-0000-000000000003' and status='draft' and not student_visible) then raise exception 'teacher A visibility attempt changed draft'; end if;
  update public.attendance_sessions set status='submitted', submitted_at=now() where id='13000000-0000-0000-0000-000000000003';
  if not exists(select 1 from public.attendance_sessions where id='13000000-0000-0000-0000-000000000003' and status='submitted' and submitted_at is not null and not student_visible) then raise exception 'teacher A could not submit owned draft securely'; end if;
  update public.attendance_sessions set student_visible=true where id='13000000-0000-0000-0000-000000000003';
  get diagnostics changed = row_count;
  if changed <> 0 or exists(select 1 from public.attendance_sessions where id='13000000-0000-0000-0000-000000000003' and student_visible) then raise exception 'teacher A changed submitted register'; end if;
  update public.attendance_sessions set status='submitted', submitted_at=now() where id='13000000-0000-0000-0000-000000000002';
  get diagnostics changed = row_count;
  if changed <> 0 then raise exception 'teacher A submitted teacher B register'; end if;
  update public.attendance_sessions set teacher_assignment_id='f0000000-0000-0000-0000-000000000015' where id='13000000-0000-0000-0000-000000000002';
  get diagnostics changed = row_count;
  if changed <> 0 then raise exception 'teacher A changed teacher B register assignment'; end if;
  if exists(select 1 from public.attendance_sessions where id='13000000-0000-0000-0000-000000000002') then raise exception 'teacher A changed teacher B register'; end if;
end $$;
select set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000006',true);
do $$ declare changed integer; begin
  if not exists(select 1 from public.assignments where id='11000000-0000-0000-0000-000000000002') or exists(select 1 from public.assignments where id='11000000-0000-0000-0000-000000000001') then raise exception 'teacher B same-tuple assignment isolation failed'; end if;
  update public.assignments set title='B private draft edited' where id='11000000-0000-0000-0000-000000000002';
  if not exists(select 1 from public.assignments where id='11000000-0000-0000-0000-000000000002' and title='B private draft edited') then raise exception 'teacher B could not edit own assignment draft'; end if;
  update public.assignment_documents set document_id='14000000-0000-0000-0000-000000000001' where assignment_id='11000000-0000-0000-0000-000000000001'; get diagnostics changed = row_count;
  if changed <> 0 then raise exception 'teacher B changed teacher A assignment document'; end if;
end $$;
-- Draft assignments are invisible to a linked family before administrator review.
select set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000007',true);
do $$ begin if exists(select 1 from public.assignments where id='11000000-0000-0000-0000-000000000003') then raise exception 'parent read assignment before publication'; end if; end $$;
-- The headmistress has assessments.review (but not results.release) and can make
-- the approved assignment transitions using the normal authenticated RLS path.
select set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000002',true);
update public.assignments set status='published', published_at=now() where id='11000000-0000-0000-0000-000000000003' and status='draft';
update public.assignments set status='closed', published_at=now() where id='11000000-0000-0000-0000-000000000002' and status='draft';
do $$ begin if not exists(select 1 from public.assignments where id='11000000-0000-0000-0000-000000000003' and status='published' and published_at is not null) then raise exception 'assessments.review admin could not publish assignment'; end if; if not exists(select 1 from public.assignments where id='11000000-0000-0000-0000-000000000002' and status='closed' and published_at is not null) then raise exception 'assessments.review admin could not close assignment'; end if; end $$;
select set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000004',true);
update public.attendance_sessions set status='submitted', submitted_at=now(), student_visible=true where id='13000000-0000-0000-0000-000000000001';
update public.attendance_sessions
set teacher_assignment_id='f0000000-0000-0000-0000-000000000015',
    session_number=2,
    timetable_entry_id='91000000-0000-0000-0000-000000000016',
    status='corrected',
    submitted_at=now(),
    student_visible=true
where id='13000000-0000-0000-0000-000000000002';
do $$ begin if not exists(select 1 from public.attendance_sessions where id='13000000-0000-0000-0000-000000000002' and teacher_assignment_id='f0000000-0000-0000-0000-000000000015' and session_number=2 and timetable_entry_id='91000000-0000-0000-0000-000000000016' and status='corrected') then raise exception 'attendance reviewer could not correct register identity'; end if; end $$;
select set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000007',true);
do $$ begin if not exists(select 1 from public.assignments where id='11000000-0000-0000-0000-000000000003' and status='published') then raise exception 'parent could not read published assignment'; end if; if not exists(select 1 from public.announcements where id='15000000-0000-0000-0000-000000000002') or not exists(select 1 from public.events where id='16000000-0000-0000-0000-000000000002') or not exists(select 1 from public.documents where id='14000000-0000-0000-0000-000000000002') then raise exception 'parent A lost class audience'; end if; if exists(select 1 from public.documents where id='14000000-0000-0000-0000-000000000003') then raise exception 'parent A read unrelated creator document'; end if; if (select count(*) from public.attendance_records) <> 1 then raise exception 'parent attendance visibility or recursion failed'; end if; if not exists(select 1 from public.timetable_entries where class_group_id='40000000-0000-0000-0000-000000000001') or exists(select 1 from public.timetable_entries where class_group_id='40000000-0000-0000-0000-000000000002') then raise exception 'parent timetable isolation failed'; end if; end $$;
select set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000009',true);
do $$ begin if exists(select 1 from public.assignments where id='11000000-0000-0000-0000-000000000003') then raise exception 'parent B crossed assignment class boundary'; end if; if exists(select 1 from public.announcements where id='15000000-0000-0000-0000-000000000002') or exists(select 1 from public.events where id='16000000-0000-0000-0000-000000000002') or exists(select 1 from public.documents where id='14000000-0000-0000-0000-000000000002') then raise exception 'parent B crossed class audience'; end if; if exists(select 1 from public.documents where id='14000000-0000-0000-0000-000000000003') then raise exception 'creator read document without an audience target'; end if; if exists(select 1 from public.attendance_records where student_id='c0000000-0000-0000-0000-000000000008') or (select count(*) from public.attendance_records) <> 1 then raise exception 'parent B attendance isolation failed'; end if; end $$;
select set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000008',true);
do $$ begin if not exists(select 1 from public.assignments where id='11000000-0000-0000-0000-000000000003' and status='published') then raise exception 'student could not read published assignment'; end if; if (select count(*) from public.attendance_records) <> 1 or exists(select 1 from public.attendance_records where student_id='c0000000-0000-0000-0000-000000000010') then raise exception 'student attendance isolation failed'; end if; if not exists(select 1 from public.timetable_entries where class_group_id='40000000-0000-0000-0000-000000000001') or exists(select 1 from public.timetable_entries where class_group_id='40000000-0000-0000-0000-000000000002') then raise exception 'student timetable isolation failed'; end if; end $$;
reset role;

-- Constraints run as owner so RLS cannot mask failures.
do $$ begin
  if not exists (select 1 from public.operational_events where entity_type = 'assessment' and entity_id = '12000000-0000-0000-0000-000000000001') or not exists (select 1 from public.operational_events where entity_type = 'attendance_session' and entity_id = '13000000-0000-0000-0000-000000000001') or not exists (select 1 from public.operational_events where entity_type = 'document' and entity_id = '14000000-0000-0000-0000-000000000001') then raise exception 'Phase 3 status audit did not emit allowed entity types'; end if;
  begin insert into public.announcement_targets values ('15000000-0000-0000-0000-000000000001','school',null,null); raise exception 'duplicate school target accepted'; exception when unique_violation then null; end;
  begin insert into public.event_targets values ('16000000-0000-0000-0000-000000000001','role',null,null); raise exception 'invalid event target accepted'; exception when check_violation then null; end;
  begin insert into public.document_targets values ('14000000-0000-0000-0000-000000000001','class','parent','40000000-0000-0000-0000-000000000001'); raise exception 'invalid document target accepted'; exception when check_violation then null; end;
  begin insert into public.attendance_sessions(class_group_id,teacher_assignment_id,attendance_date,status) values ('40000000-0000-0000-0000-000000000099','f0000000-0000-0000-0000-000000000099','2026-09-02','draft'); raise exception 'historical assignment accepted for current date'; exception when check_violation then null; end;
  begin insert into public.attendance_sessions(class_group_id,teacher_assignment_id,attendance_date,timetable_entry_id,status) values ('40000000-0000-0000-0000-000000000001','f0000000-0000-0000-0000-000000000005','2026-09-03','91000000-0000-0000-0000-000000000005','draft'); raise exception 'mismatched timetable date accepted'; exception when check_violation then null; end;
end $$;
set local role authenticated; select set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000007',true); do $$ begin begin if exists(select 1 from storage.objects where bucket_id='school-documents') then raise exception 'storage objects unexpectedly readable'; end if; exception when insufficient_privilege then null; end; end $$; reset role;
rollback;
\echo 'PASS: Phase 3 operations hardening, constraints, non-recursive RLS, and storage default-deny tests'
