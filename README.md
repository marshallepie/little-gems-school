# Little Gems School — Phase 3 Batch 3 assignments and results workflows

This repository contains the approved **Native Next.js + Supabase foundation, Phase 1 identity and school structure, and Phase 2 role-specific dashboards**. It includes Supabase email/password and reset flows, protected role routes, the existing admin-only mobile-first school-structure workspace, concise role-specific read-only dashboards, SSR Supabase client/proxy wiring, and relationship-oriented schema/RLS. It intentionally does **not** implement CMS, storage, payments, communications, cloud provisioning, production Supabase, or real accounts/data beyond the approved fictional local seed.

## Prerequisites

- Node.js 20.9+ (this foundation was verified with Node 26)
- Docker running locally
- Supabase CLI available through `npx supabase`

## Local setup

```bash
npm install
npx supabase start
npx supabase status
cp .env.example .env.local
```

Copy the **API URL** and **Publishable key** reported by `supabase status` into `.env.local`. Never put a service-role key in `NEXT_PUBLIC_*` or commit credentials.

Apply the append-only migration and deterministic, fictional reference seed data:

```bash
npx supabase db reset
```

Run the application and quality gates:

```bash
npm run dev
npm run test
npm run typecheck
npm run lint
npm run build
```

Without the two public environment variables, public/auth pages remain usable and `/dashboard` fails safely by routing to login. Configure local Supabase before testing real email/password and password-reset flows. Initial accounts and role assignments remain an approved administrative provisioning workflow; the browser never receives a service-role key.

## Phase 2 dashboards

`/dashboard` applies the centralized authenticated completion guard and routes users by their normalized default role. Each dashboard is a server-rendered, read-only view; relationship RLS remains the data boundary.

- **Administrator:** `/admin/dashboard` uses `requireAdminPermission('school_records.read')` for a concise school-at-a-glance view. It links to the existing `/admin` school-structure workspace. The `/admin/accounts` account-lifecycle link is rendered only after the server verifies the active proprietor position using `is_proprietor`.
- **Teacher:** `/teacher` retains `requireRole()` and shows only the signed-in teacher's assignments, together with rosters for assigned classes. It has clear no-record/no-assignment states.
- **Parent or guardian:** `/parent` retains `requireRole()` and shows only children linked through the signed-in guardian's relationship, with each child's active class context in mobile-friendly cards.
- **Student:** `/student` retains `requireRole()` and shows only the signed-in student's identity and active class context.

## Phase 3 Batches 2–3: operations, assignments, and results

These server-rendered, mobile-first routes use the approved Phase 3 schema/RLS foundation only. They do not change migrations, RLS policies, production Supabase, or use a service-role credential in portal workflows.

- **Teachers:** `/teacher/assignments` validates a selected, owned teaching assignment and term before it writes drafts. `/teacher/assessments` creates only draft assessments, validates an optional linked assignment against the same teaching assignment/term, calculates the roster on the assessment date server-side, and upserts results only for that roster while enforcing the maximum score. Teachers have no release action.
- **Assessment review:** `/admin/operations/assessments` requires `assessments.review` server-side. It may publish draft assessments for review. The release control is rendered only after a server-side `results.release` permission check and its server action independently requires `results.release`; only the proprietor and senior administrator receive that permission. Headmistress can review but cannot release.
- **Families:** `/parent/children/[studentId]/assignments` and `/results` explicitly prove the signed-in guardian-to-child link before reading. `/student/assignments` and `/results` first resolve the signed-in student record. Assignment views query published work for the relevant active class; result views filter the parent assessment to `released`. RLS remains the enforcement boundary in addition to these server-side relationship checks.
- **Existing Batch 2 routes:** timetable and attendance remain as described below. The supplied Batch 1 RLS policy deliberately rejects a teacher transition from `draft` to `submitted` for attendance; without an approved RLS/RPC change, the Submit action truthfully returns the database denial rather than bypassing it.

The approved assignments teacher policy permits teachers to create and edit their own drafts. Its `WITH CHECK status = 'draft'` also prevents a teacher session from transitioning a draft to `published` or `closed`. The assignment screen makes a normal cookie-bound request and surfaces that database denial; it does not bypass the policy with a service role. Enabling teacher publication/archival requires an approved database policy or narrowly scoped security-definer workflow outside this batch.

Room data is not collected because `timetable_entries` has no room column in the approved schema.

## Internal communications and private calendar slice

`/admin/communications` and `/admin/calendar` use the normal cookie-bound authenticated session, then make one narrow database command RPC per mutation. The RPC verifies the active manager permission, normalizes and validates a nonempty whole-school/role/current-class target set, replaces targets atomically with draft edits/publication, sets immutable creator provenance from `auth.uid()`, and emits append-only structured `operational_events`. Direct authenticated writes to records, targets, and audit rows have no RLS write policy. Announcements are created as drafts, drafts may be edited/published, published records may only be archived, and archived records are terminal. Events follow the same draft/edit/publish lifecycle, with published records cancellable and cancelled records terminal. A publication cannot occur without a valid audience.

`/teacher`, `/parent`, and `/student` navigation links to read-only `/communications` and `/calendar` feeds. Parent pages first prove a guardian relationship; every feed still uses audience RLS. The calendar UI truthfully labels `datetime-local` values as UTC; server validation rejects malformed/impossible dates and end times that are not after start. The “Updates indicator” is non-authoritative: it has no unread count, delivery claim, or durable read state. This scope excludes delivery channels, realtime, rich text, public-event integration, and the separate security-hardening work.

Application timestamp/audience validation is covered by `lib/validations/communications.test.ts`. `supabase/tests/phase3_communications_calendar_rls.sql` is a self-contained, single-transaction behavioural test and is invoked by `scripts/db-behavioural-validate.sh`; it has not been run in this environment because Docker/Supabase is unavailable.

## Administrative authorization hierarchy

The portal roles remain `admin`, `teacher`, `parent`, and `student`. Administrative access is further constrained by one active position and explicit permissions: `proprietor_super_admin` (Tier 1), `senior_administrator` (Tier 2), and `headmistress` (Tier 3). The migration deliberately replaces—rather than adds beside—the old permissive `has_role('admin')` RLS policies, because permissive policies OR-combine. An unpositioned legacy `admin` is default-denied after the cutover.

See [`supabase/ADMINISTRATIVE_AUTHORIZATION.md`](supabase/ADMINISTRATIVE_AUTHORIZATION.md) for the permission matrix and the **required, executable one-time production bootstrap** for a zero-user/empty-migration project. It creates exactly the three authorized no-email Auth accounts only from a restricted server/service-role terminal, maps normalized admin roles and positions through an operator-only one-time database transaction, validates the result, then resumes ordinary `supabase db push`. Never hard-code UUIDs, put service keys in browser code, or put temporary passwords in repository files, commands, logs, or tickets.

## Security boundary

`auth.users` remains Supabase-owned. App roles are normalized in `roles`/`user_roles`, not JWT metadata. Server checks use `auth.getClaims()` rather than authorizing from `getSession()`; `proxy.ts` refreshes session cookies. UI redirects are only UX—the database uses RLS with default deny and private `app_private` helper functions as the enforcement boundary.

## Account lifecycle and first-login profile completion

Only the active `proprietor_super_admin` position can use `/admin/accounts`. The server action checks that exact database position before it creates an Auth account with `auth.admin.createUser`; it never uses invitations. It generates a password only in memory and displays it once to the authenticated proprietor for approved secure delivery. Configure `SUPABASE_SERVICE_ROLE_KEY` **only** in the server runtime—never as `NEXT_PUBLIC_*` or in client code.

“Deprovision” is implemented as audited deprovisioning, not a destructive Auth delete: it immediately revokes normalized roles and administrator positions and marks the profile inactive, preserving linked student/staff/guardian records and audit history. That transaction writes a durable pending Auth-ban state. The server action first proves the requester’s active proprietor position through the normal session, then uses a server-only service-role capability to record the Auth-ban outcome with that original actor identity. Browser JWTs cannot execute either outcome RPC. If Auth fails (or durable completion recording fails), database authorization remains denied, the account is marked for retry on `/admin/accounts`, and only the proprietor can retry the idempotent ban. Once the ban is durably `succeeded`, a proprietor may re-provision a non-proprietor account from that page: a new in-memory temporary password is set and the Auth ban is removed before the server-only database capability restores the selected normalized role and eligible Tier 2/3 administrator position. If database activation fails, the action re-bans an account only after confirming its profile remains inactive, so an Auth failure can never leave a database-active account and a failed activation remains denied for operator review. The audit records the re-provision lifecycle event without a password or other metadata. Active accounts, Auth-ban pending/failed accounts, and any proprietor-super-admin record cannot be re-provisioned. The same proprietor-only page lists active administrator position assignments and the latest authorization events, and can assign, replace, or revoke Tier 2/3 positions for active existing admin accounts; it cannot change the bootstrap-only proprietor position or the requester’s own position. Active `proprietor_super_admin` accounts—including another active owner—cannot be deprovisioned through this path; ownership succession is operator-only. The proprietor cannot deprovision their own account.

The first-login completion guard is centralized in the authenticated server guards used by every portal route and sensitive server action. A user without `profile_completed_at` is therefore redirected to `/profile` even when directly opening `/admin`, `/admin/dashboard`, `/admin/accounts`, `/teacher`, `/parent`, `/student`, or `/dashboard`; `/profile` and auth/recovery routes remain outside the guard.

## Phase 4: public website and CMS

The public site now provides responsive, accessible Home, About, Academics, Admissions, News, Events, and Contact pages, with a persistent School Login entry and metadata/Open Graph defaults. Approved hero, proprietress, vision/mission, and achievement copy are rendered as HTML; Academics, Admissions, and Contact deliberately state that current details must be confirmed with the school rather than inventing them. Public news and events safely render empty states when Supabase public environment variables are absent.

`/admin/cms` is server-protected by `requireAdminPermission('website.manage')`. Its Zod-validated server actions manage plain-text pages, news posts, and public events, then revalidate the affected public and admin routes. The append-only `20260902000000_phase4_public_cms.sql` adds separate CMS tables and RLS: anonymous/authenticated visitors can read only `published` records whose `published_at` is not in the future, while authenticated administrators with `website.manage` may write. Database triggers assign `created_by` from `auth.uid()` on insert and reject later changes. It intentionally does not change Phase 3's private `events` table or its `is_public = false` constraint.

`supabase/tests/phase4_public_cms_rls.sql` is the added SQL behavioral test for past-versus-future public visibility and `created_by` assignment/immutability. **Remaining database-validation gate:** run it against the local Supabase database once the local Docker daemon is available; it has not been executed in this environment.

**Content/asset blockers:** the repository only contains the school crest in `public/images`; the documented event, building, ICT, and award photos still need supplied/approved web assets. The school must approve current admissions requirements/fees/dates, academic programmes/curriculum/facilities details, and contact address/phone/email/hours before they are published. A real public production URL is also required before adding a canonical metadata base URL.

## Before any live authentication or data

An approved Supabase project, credentials, privacy/legal and retention decisions, identity/invitation workflow, stakeholder workflow decisions, fuller RLS test coverage, and staging/backup procedures are still required. Do not add real pupils, staff, guardians, or production exports to local seed data.
