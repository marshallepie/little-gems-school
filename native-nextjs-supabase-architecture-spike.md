# Little Gems School Platform — Native Next.js + Supabase Architecture & Schema Spike

**Date:** 2026-08-27  
**Status:** Design complete — **approval required before implementation**  
**Authority:** [`PRD.md`](PRD.md) is the authoritative Native Next.js + Supabase MVP brief. The Gibbon reports are retained only as superseded history.

## 1. Recommendation and scope boundary

Build one **native Next.js App Router + TypeScript** application, backed by **Supabase Auth, Postgres, Storage and RLS**. Use no Gibbon, PHP, WordPress, MySQL, microservices, or separate CMS.

- Public content is server-rendered/static where safe; authenticated portal data is dynamic and never shared in public caches.
- Pages and layouts are Server Components by default. Use small Client Components only for interactions such as attendance marking, child switching, forms, and responsive navigation.
- Use Supabase's cookie-based SSR pattern (`@supabase/ssr`): browser and server clients plus the current Next.js `proxy.ts` session-refresh pattern. Validate identity with `auth.getClaims()`; do **not** authorize server requests from `getSession()`.
- RLS is the enforcement boundary. Route guards and server actions improve UX but never replace database authorization.
- No external integration, payments, messaging delivery, AI, realtime dependency, or full LMS is needed for MVP.

**Version/pattern sources consulted (2026-08-27):**

1. [Next.js installation](https://nextjs.org/docs/app/getting-started/installation) — latest documented version **16.3.3**, App Router, TypeScript, Tailwind, Node 20.9+ baseline, and separate lint command in Next 16.
2. [Next.js Server and Client Components](https://nextjs.org/docs/app/getting-started/server-and-client-components) — Server Components by default and narrow `"use client"` boundaries.
3. [Next.js data fetching](https://nextjs.org/docs/app/getting-started/fetching-data) and [caching](https://nextjs.org/docs/app/guides/caching) — fetches are not cached by default; choose explicit caching/revalidation per public route and keep authenticated routes dynamic.
4. [Supabase Next.js SSR](https://supabase.com/docs/guides/auth/server-side/nextjs) — `@supabase/ssr`, cookie clients, `proxy`, and `getClaims()` guidance.
5. [Supabase RLS](https://supabase.com/docs/guides/database/postgres/row-level-security) — enable RLS for every exposed table, index policy predicates, use `(select auth.uid())`, do not trust mutable `user_metadata`, and never expose privileged keys.
6. [Supabase Storage access control](https://supabase.com/docs/guides/storage/security/access-control) — policies on `storage.objects`; private bucket access is denied until explicitly granted.
7. [Supabase migrations](https://supabase.com/docs/guides/deployment/database-migrations) and [CLI local development](https://supabase.com/docs/guides/local-development/cli/getting-started) — SQL migrations in `supabase/migrations`, committed local config, `supabase db reset` as the repeatable schema/seed test.

Pin actual dependency and CLI versions in the implementation repository; recheck the above docs at bootstrap rather than treating the noted versions as a long-term pin.

## 2. Proposed repository structure

```text
little-gems-school/
├── app/
│   ├── (public)/                 # public layouts/pages: home, about, academics, admissions, news, events, contact
│   ├── (auth)/login/             # login, reset-password, update-password
│   ├── admin/                    # role-specific route group/layout
│   ├── teacher/
│   ├── parent/
│   ├── student/
│   ├── api/                      # only bounded webhook/health or privileged endpoints when justified
│   ├── forbidden.tsx  not-found.tsx  error.tsx
│   └── layout.tsx
├── components/
│   ├── public/ portal/ cms/ ui/  # reusable, accessible presentation components
├── features/                     # domain-specific queries/actions/validation, e.g. attendance/
├── lib/
│   ├── supabase/{browser,server,proxy}.ts
│   ├── auth/                     # role/landing helpers; convenience only, RLS remains authority
│   ├── validations/              # Zod schemas shared by forms/actions
│   └── data/                     # server-only query functions
├── supabase/
│   ├── migrations/               # append-only, timestamped SQL including RLS and Storage policies
│   ├── tests/                    # pgTAP RLS/constraint tests
│   ├── seed.sql                  # non-production fixture data only
│   └── config.toml
├── tests/{unit,integration,e2e}/
├── public/                       # small immutable build assets only; not school-managed uploads
├── docs/                         # implementation/runbook material if/when a code repository is initialized
└── proxy.ts
```

Keep this existing project directory for product documentation. Initialize the app only after approval; do not create a second portal, CMS, or backend service.

## 3. Identity, roles and permission model

`auth.users` is Supabase-owned identity. Application tables must never duplicate password or session fields.

| Role | Principal record | MVP authority |
|---|---|---|
| `admin` | `profiles` + `user_roles` | school-wide CRUD, CMS, users, release/publish actions |
| `teacher` | `profiles` + `teachers` + `user_roles` | only assigned class/subject data; attendance, homework, permitted scores |
| `parent` | `profiles` + `guardians` + `user_roles` | read only for linked children, released results, relevant resources |
| `student` | `profiles` + `students` + `user_roles` | own permitted records only |

Use normalized `roles(code)` and `user_roles(user_id, role_id)` rather than client-editable JWT metadata. A person may hold more than one role. On login, route to the role selected in a `profiles.default_role_code` field only if assigned; otherwise show a minimal role chooser. Admin assignment is a controlled admin operation, not self-service.

Create narrowly scoped, `SECURITY DEFINER` helper functions in a non-exposed schema with a fixed `search_path`, e.g. `app_private.has_role(code)`, `is_guardian_of(student_id)`, `is_student_self(student_id)`, `teaches_class(class_group_id)`, and `teaches_subject_in_class(class_group_id, subject_id)`. Grant execute only as required. These remove policy duplication and avoid recursive RLS joins. Do not place authorization in `auth.users.raw_user_meta_data`; it is user-editable. Do not rely solely on JWT role claims because role removal may not take effect until token refresh.

## 4. PostgreSQL data model and ER description

### Conventions

- All app primary keys: `uuid primary key default gen_random_uuid()`; all date-times: `timestamptz`; all business dates: `date`.
- Add `created_at`, `updated_at`, and (where relevant) `created_by` / `updated_by`; a trigger maintains `updated_at`.
- Use `citext` for normalized emails only if required; store names as `text`; add explicit check constraints/enums for finite values. Do not use arbitrary JSON for relationships.
- `public` contains data only when it must be queried through Supabase's data API. Put helper functions in `app_private` and revoke direct API access to that schema.

### Exact suggested tables

**Identity and people**

- `profiles(id uuid pk references auth.users(id) on delete cascade, display_name, phone, default_role_code, is_active)`
- `roles(id uuid pk, code unique check in ('admin','teacher','parent','student'), name)`
- `user_roles(user_id references profiles, role_id references roles, primary key(user_id, role_id))`
- `students(id uuid pk, profile_id unique nullable references profiles, admission_number unique, first_name, last_name, date_of_birth nullable, status)`
- `teachers(id uuid pk, profile_id unique references profiles, staff_number unique, first_name, last_name, employment_status)`
- `guardians(id uuid pk, profile_id unique references profiles, first_name, last_name, phone, email nullable)`
- `student_guardians(student_id references students, guardian_id references guardians, relationship, is_primary_contact, primary key(student_id, guardian_id))`

A student may be provisioned without a portal account (`students.profile_id is null`); a guardian may be present before account invitation. This supports staged onboarding without falsely treating a contact record as an authenticated account.

**Academic structure**

- `academic_years(id uuid pk, name unique, starts_on, ends_on, is_current)`
- `terms(id uuid pk, academic_year_id references academic_years, name, starts_on, ends_on, unique(academic_year_id, name))`
- `class_groups(id uuid pk, academic_year_id references academic_years, name, level, homeroom_teacher_id nullable references teachers, unique(academic_year_id, name))` — product wording remains “Classes”; this avoids ambiguity with language/framework terms.
- `subjects(id uuid pk, code unique, name, is_active)`
- `class_enrolments(id uuid pk, student_id references students, class_group_id references class_groups, starts_on, ends_on nullable, status, unique(student_id, class_group_id, starts_on))`
- `teacher_assignments(id uuid pk, teacher_id references teachers, class_group_id references class_groups, subject_id references subjects, term_id nullable references terms, unique(teacher_id, class_group_id, subject_id, term_id))`
- `timetable_entries(id uuid pk, class_group_id references class_groups, subject_id references subjects, teacher_id nullable references teachers, term_id references terms, weekday smallint check (weekday between 1 and 7), starts_at time, ends_at time, room nullable, unique(class_group_id, term_id, weekday, starts_at))`

**Operations**

- `attendance_sessions(id uuid pk, class_group_id references class_groups, attendance_date, session_label default 'morning', recorded_by references profiles, unique(class_group_id, attendance_date, session_label))`
- `attendance_records(id uuid pk, attendance_session_id references attendance_sessions on delete cascade, student_id references students, status check in ('present','absent','late','excused'), note nullable, unique(attendance_session_id, student_id))`
- `homework_assignments(id uuid pk, class_group_id references class_groups, subject_id references subjects, teacher_id references teachers, title, description, issued_on, due_on nullable, attachment_path nullable, published_at nullable, created_by references profiles)`
- `assessments(id uuid pk, academic_year_id references academic_years, term_id references terms, class_group_id references class_groups, subject_id references subjects, title, max_score numeric check (max_score > 0), assessed_on, created_by references profiles)`
- `assessment_results(id uuid pk, assessment_id references assessments on delete cascade, student_id references students, score numeric check (score >= 0), comment nullable, released_at nullable, unique(assessment_id, student_id))`
- `announcements(id uuid pk, title, body, status check in ('draft','published','archived'), published_at nullable, expires_at nullable, created_by references profiles)`
- `announcement_roles(announcement_id references announcements on delete cascade, role_id references roles, primary key(announcement_id, role_id))`
- `announcement_class_groups(announcement_id references announcements on delete cascade, class_group_id references class_groups, primary key(announcement_id, class_group_id))`
- `events(id uuid pk, title, description, starts_at, ends_at nullable, location nullable, image_path nullable, is_public boolean default false, status check in ('draft','published','cancelled'), created_by references profiles)`
- `event_roles(event_id references events on delete cascade, role_id references roles, primary key(event_id, role_id))`
- `event_class_groups(event_id references events on delete cascade, class_group_id references class_groups, primary key(event_id, class_group_id))`
- `documents(id uuid pk, title, storage_path unique, bucket_id, mime_type, byte_size, visibility check in ('role','class','private'), uploaded_by references profiles, published_at nullable)`
- `document_roles(document_id references documents on delete cascade, role_id references roles, primary key(document_id, role_id))`
- `document_class_groups(document_id references documents on delete cascade, class_group_id references class_groups, primary key(document_id, class_group_id))`

**Small CMS**

- `content_pages(id uuid pk, slug unique, title, body_markdown, featured_image_path nullable, status check in ('draft','published'), seo_title nullable, seo_description nullable, published_at nullable, updated_by references profiles)`
- `news_posts(id uuid pk, slug unique, title, body_markdown, featured_image_path nullable, status check in ('draft','published'), published_at nullable, author_id references profiles, seo_title nullable, seo_description nullable)`

Add indexes for all foreign keys and RLS lookup paths: `student_guardians(guardian_id, student_id)`, active `class_enrolments(student_id, class_group_id)`, `teacher_assignments(teacher_id, class_group_id, subject_id)`, `assessment_results(student_id, assessment_id)`, and publish/listing indexes such as `(status, published_at desc)`.

### ER narrative

`auth.users → profiles` is one-to-one. `profiles` gains one-or-more roles through `user_roles → roles`, and may link one-to-one to a student, teacher, or guardian record. A `guardian` and `student` are many-to-many through `student_guardians`. A student belongs to academic-year class groups through `class_enrolments`; a teacher is authorized to a class/subject through `teacher_assignments`. That academic structure owns timetable entries, attendance sessions/records, homework, assessments/results, and class-targeted communications. An assessment has many student results; a result belongs to exactly one student and is visible only after `released_at`. Announcements, events, and documents have explicit role/class target bridges rather than an opaque target JSON array. Pages and news are independent public CMS records.

### `school_id` migration path — no premature multi-tenancy

**MVP:** do **not** create `schools`, add `school_id`, tenant JWT claims, or tenant-aware UI. One Supabase project/database represents Little Gems; RLS is relationship/role based.

**Later, only when a second school is approved:** (1) add `schools`; (2) create and backfill a single Little Gems row; (3) add nullable `school_id` to every school-owned table above, then backfill and make it `not null`; (4) add school-scoped unique/index constraints and composite foreign keys where needed; (5) replace helpers/RLS with school-scoped membership checks; (6) migrate `user_roles` to school memberships/roles; (7) test cross-school denial before allowing a second tenant. The UUID-based model and explicit bridge tables make this additive migration feasible without pretending the MVP is multi-tenant.

## 5. Initial RLS matrix

Enable RLS and explicit grants on **every exposed `public` table**; default deny. Security-definer helpers must not be exposed through the data API. “Own” below means a verified relationship, not a client-supplied ID.

| Data area | Admin | Teacher | Parent | Student | Anonymous |
|---|---|---|---|---|---|
| `profiles`, roles | own profile; admin manages app roles | own profile | own profile | own profile | none |
| students/guardians/enrolments | full CRUD | select students in active assigned classes; no guardian contact mutation | select linked children/basic relevant data | select own permitted profile | none |
| academic years, terms, subjects, class groups | CRUD | select assigned/current structure | select linked child structure | select own structure | none |
| teacher assignments/timetable | CRUD | select own assignments + relevant timetable | child timetable only | own timetable only | none |
| attendance | full select/review; controlled correction | create/update only assigned class session/records | select linked child records | select own only **if stakeholder enables it** | none |
| homework | CRUD | CRUD only own assigned class/subject | select linked child class assignments published | select own enrolled class assignments published | none |
| assessments/results | CRUD and release | create/update for assigned class/subject; no arbitrary release | select linked child results only where `released_at is not null` | same for own released results | none |
| announcements/events/documents | CRUD/publish | select targeted/published; no publish unless separately delegated | select public or targeted by role/child class | same | public published `content_pages`, `news_posts`, and `events.is_public` only |
| CMS content pages/news | CRUD | no write | no write | no write | select `status='published'` only |
| `storage.objects` | controlled bucket/object admin | scoped upload/read only (homework attachment paths) | read authorized private document paths | read authorized private document paths | public bucket objects only |

Policy implementation notes:

- Use `auth.uid() is not null` and `(select auth.uid())` in predicates. A teacher policy must derive assignment from DB bridges, never trust a submitted class ID.
- Parent/Student policies must cover `SELECT` **and** table joins/indirect access. Published/released conditions belong in the policy, not only page filtering.
- Prefer an explicit “admin can correct” workflow and audit timestamps over broad delete rights. Initial MVP records should be soft archived/status changed where practical; no ordinary role deletes people or results.
- Admin-only user invitation/reset uses a server-only Route Handler or Edge Function: first validate the caller using their ordinary authenticated Supabase context and database role, then invoke the Auth Admin API with a secret key. The secret key is never prefixed `NEXT_PUBLIC_`, never returned, and never used for routine data access.

## 6. Storage, CMS, and route map

### Storage

| Bucket | Visibility | Object path / use | Access |
|---|---|---|---|
| `public-assets` | public | `site/{content-id-or-slug}/...`; published website images | public read; admin-only upload/update/delete via `storage.objects` policy |
| `private-documents` | private | `documents/{document-id}/{safe-filename}`; policies/forms/resources | access only if `documents` RLS target permits; serve via authenticated download or short-lived signed URL |
| `assignment-attachments` | private | `assignments/{assignment-id}/{safe-filename}` | teacher assigned to the class uploads; enrolled student/linked guardian reads only after assignment is published |

Do not make a private bucket public for convenience. Store opaque UUID paths, validate MIME type/size server-side, strip unsafe filenames, and keep `documents` metadata as the authorization/audit record. Do not store child photos in `public-assets` without specific consent and a documented public-use decision.

### CMS

Use `content_pages`, `news_posts`, and public `events` only. Admin CMS forms validate title/slug/status/meta/body with Zod. Store body as Markdown/plain structured text and render through a vetted sanitizer; do not add a rich-text editor, plugins, revisions product, or page builder in MVP. A page publish/update calls `revalidatePath`/tag revalidation for the affected public route. Authenticated portal pages must remain dynamic and must not receive CDN-shared responses carrying `Set-Cookie`.

### Route map

```text
/                         public home                  /about
/academics                /admissions                  /news
/news/[slug]              /events                      /contact
/login                    /forgot-password             /update-password
/dashboard                role resolver → /admin | /teacher | /parent | /student
/admin                    /admin/students              /admin/guardians
/admin/teachers           /admin/academic-structure    /admin/enrolments
/admin/timetable          /admin/attendance            /admin/assessments
/admin/announcements      /admin/events                /admin/documents
/admin/content/pages      /admin/content/news          /admin/users
/teacher                  /teacher/classes/[classId]   /teacher/attendance/[classId]
/teacher/assignments      /teacher/assessments         /teacher/timetable
/parent                   /parent/children/[studentId] /parent/children/[studentId]/attendance
/parent/children/[studentId]/timetable                 /parent/children/[studentId]/homework
/parent/children/[studentId]/results                   /parent/documents
/student                  /student/timetable           /student/homework
/student/attendance       /student/results             /student/documents
```

Each portal route has a server-side role/relationship check for clear redirects/403s; database RLS is still checked on every query. Do not use a single mega-dashboard with hidden buttons.

## 7. Migrations, seed data, and tests

### Migrations

Use the Supabase CLI with append-only timestamped SQL migrations. Suggested order: extensions/enums and private helpers; profiles/roles/auth trigger; people; academic structure; operational tables; CMS; indexes/constraints; RLS/grants; Storage buckets/policies; fixture support. Keep schema, functions, grants, RLS, and bucket policies in migration files—not dashboard-only changes. Test every migration with `supabase db reset`; only then apply through a controlled staging/production migration pipeline. Never edit production schema manually once migrations exist.

### Seed data

`supabase/seed.sql` contains fictional, non-sensitive fixture people and a deterministic current academic year/term, two classes, subjects, enrolments, teacher assignments, a timetable, all attendance statuses, draft/released results, public/targeted announcements, and published/draft CMS records. Seed four test identities for admin/teacher/parent/student using local Auth-safe provisioning; never seed real pupils, contacts, credentials, images, or production exports. Document test credentials only in local developer instructions outside committed secrets.

### Testing strategy

1. **Database:** pgTAP/SQL tests for constraints, trigger-created profiles, uniqueness, helper functions, and every RLS allow/deny boundary. Run tests as each role and assert cross-child, cross-class, cross-student, unpublished, and unreleased reads fail.
2. **Unit:** Vitest for date/score/status logic, permissions convenience functions, and Zod validation.
3. **Integration:** local Supabase tests for Server Actions/Route Handlers, upload authorization, signed private downloads, publish/release behavior, and cache revalidation.
4. **E2E:** Playwright mobile viewport flows: login/landing, parent child switch, teacher attendance submit, admin release result, parent reads released result but not sibling/unrelated child, CMS public publish, and a direct denied URL/API attempt.
5. **Quality/security:** `tsc --noEmit`, separate `eslint` command, production `next build`, dependency/security review, keyboard/screen-reader/accessibility checks, Android-class viewport and throttled-network checks. Before pilot, rehearse Supabase backup/restore evidence in staging.

## 8. Open decisions requiring stakeholder input

1. Attendance: is it one morning session, multiple sessions, and may students view their own attendance? Confirm correction/approval rules.
2. Academic structure: grades/levels, class naming, subjects, academic-year/term dates, timetable periods/rooms, and whether teachers can have multiple assignments per term.
3. Results: grading scale, score decimals, teacher edit window, who releases results, and whether comments/report cards are required in MVP.
4. Parent/guardian governance: invitation proof/approval, multiple guardian access, guardian removal process, and whether a parent can view sibling data by default once linked.
5. Student accounts: minimum age/policy, who provisions credentials, and consent for student self-service.
6. Documents: exact categories, upload size/type limits, retention, whether parents/students may upload anything (recommended: no in MVP), and public-image consent.
7. CMS: named content administrators, approval/publishing workflow (recommended: one admin author/publisher in MVP), Admissions form requirements, and final public contact details.
8. Privacy/legal: legal review of Nigeria Data Protection Act obligations, retention/deletion schedule, consent wording, data residency expectations, breach contact/process, and who may export pupil data.
9. Operations: student/staff counts, import source quality, hosting/account owner, domain and mail sender, staging approver, backup recovery objective, and support/onboarding owner.

## 9. Risk register

| Risk | Level | Mitigation / decision |
|---|---|---|
| Child-data overexposure through weak relationship policies | Critical | DB-enforced RLS, normalized bridges, deny tests for every role, private Storage, no service key in browser |
| Incorrect guardian links or account invitation | High | admin verification workflow, audit timestamps, staged invitation, immediate revocation procedure |
| Authenticated response cached/shared | High | dynamic portal routes; follow Supabase SSR cookie/proxy guidance; only cache explicit public content |
| Ambiguous school workflows expand MVP | High | obtain open decisions; milestone scope gates; defer report cards, LMS, payments and messaging delivery |
| Data migration quality (duplicates/missing relationships) | High | mapping template, dry-run import, reconciliation counts, staged pilot—not direct production import |
| Storage data disclosure / malware | High | private buckets/policies, MIME/size allowlists, UUID paths, malware scanning decision before broad uploads |
| Slow/mobile-network experience | Medium | server-first UI, optimized images, pagination, targeted queries, low-end Android/throttled E2E checks |
| Privileged Auth Admin API misuse | Medium | isolated server-only implementation, caller role check before privilege, secrets manager, audit logging |
| Supabase/Next version changes | Medium | pin working versions, migration/test gate, recheck official docs before bootstrap and upgrades |
| Privacy/backup obligations undefined | High | stakeholder/legal approval, documented retention and tested staged restore before pilot |

## 10. Implementation milestones after approval

1. **Foundation:** create the one Next.js repository, pin dependencies/CLI, local Supabase, env template, CI quality gates, migration baseline, SSR clients/proxy. No user-facing feature beyond verified secure shell.
2. **Identity and school structure:** profile trigger, roles/RLS tests, people, guardian links, academic structure, imports, representative fixture data.
3. **Role portals:** portal shells and only role-relevant dashboards/navigation; test landing and relationship boundaries.
4. **Core operations:** timetable, attendance, homework, assessments/results, announcements, events, documents, with RLS and mobile E2E coverage per workflow.
5. **Public site/CMS:** content pages/news/events, asset handling, metadata, accessible responsive presentation, CMS publishing and cache invalidation.
6. **Hardening/pilot:** data-import rehearsal, cross-role/security suite, performance/accessibility/mobile checks, backup/restore test, stakeholder UAT, staging pilot. Production only after acceptance.

## 11. Design conclusion

The smallest viable solution is one server-first Next.js application with Supabase as the managed backend and a normalized, relationship-driven Postgres schema. It satisfies the four role portals and editable public site without inventing a second CMS/backend or prematurely building SaaS tenancy. **Stop here pending stakeholder answers and approval of this design; do not bootstrap the application or create Supabase services yet.**
