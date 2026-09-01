# Little Gems School — Phase 2 role-specific dashboards

This repository contains the approved **Native Next.js + Supabase foundation, Phase 1 identity and school structure, and Phase 2 role-specific dashboards**. It includes Supabase email/password and reset flows, protected role routes, the existing admin-only mobile-first school-structure workspace, concise role-specific read-only dashboards, SSR Supabase client/proxy wiring, and relationship-oriented schema/RLS. It intentionally does **not** implement Phase 3 operations, CMS, storage, payments, communications, cloud provisioning, or real accounts/data.

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

Attendance, grades, lesson planning, reports, payments, messaging, and other operational workflows are explicitly deferred to later phases; dashboard labels do not imply those workflows exist.

## Administrative authorization hierarchy

The portal roles remain `admin`, `teacher`, `parent`, and `student`. Administrative access is further constrained by one active position and explicit permissions: `proprietor_super_admin` (Tier 1), `senior_administrator` (Tier 2), and `headmistress` (Tier 3). The migration deliberately replaces—rather than adds beside—the old permissive `has_role('admin')` RLS policies, because permissive policies OR-combine. An unpositioned legacy `admin` is default-denied after the cutover.

See [`supabase/ADMINISTRATIVE_AUTHORIZATION.md`](supabase/ADMINISTRATIVE_AUTHORIZATION.md) for the permission matrix and the **required, executable one-time production bootstrap** for a zero-user/empty-migration project. It creates exactly the three authorized no-email Auth accounts only from a restricted server/service-role terminal, maps normalized admin roles and positions through an operator-only one-time database transaction, validates the result, then resumes ordinary `supabase db push`. Never hard-code UUIDs, put service keys in browser code, or put temporary passwords in repository files, commands, logs, or tickets.

## Security boundary

`auth.users` remains Supabase-owned. App roles are normalized in `roles`/`user_roles`, not JWT metadata. Server checks use `auth.getClaims()` rather than authorizing from `getSession()`; `proxy.ts` refreshes session cookies. UI redirects are only UX—the database uses RLS with default deny and private `app_private` helper functions as the enforcement boundary.

## Account lifecycle and first-login profile completion

Only the active `proprietor_super_admin` position can use `/admin/accounts`. The server action checks that exact database position before it creates an Auth account with `auth.admin.createUser`; it never uses invitations. It generates a password only in memory and displays it once to the authenticated proprietor for approved secure delivery. Configure `SUPABASE_SERVICE_ROLE_KEY` **only** in the server runtime—never as `NEXT_PUBLIC_*` or in client code.

“Deprovision” is implemented as audited deprovisioning, not a destructive Auth delete: it immediately revokes normalized roles and administrator positions and marks the profile inactive, preserving linked student/staff/guardian records and audit history. That transaction writes a durable pending Auth-ban state. The server action first proves the requester’s active proprietor position through the normal session, then uses a server-only service-role capability to record the Auth-ban outcome with that original actor identity. Browser JWTs cannot execute either outcome RPC. If Auth fails (or durable completion recording fails), database authorization remains denied, the account is marked for retry on `/admin/accounts`, and only the proprietor can retry the idempotent ban. The same proprietor-only page lists active administrator position assignments and the latest authorization events, and can assign, replace, or revoke Tier 2/3 positions for active existing admin accounts; it cannot change the bootstrap-only proprietor position or the requester’s own position. Active `proprietor_super_admin` accounts—including another active owner—cannot be deprovisioned through this path; ownership succession is operator-only. The proprietor cannot deprovision their own account.

The first-login completion guard is centralized in the authenticated server guards used by every portal route and sensitive server action. A user without `profile_completed_at` is therefore redirected to `/profile` even when directly opening `/admin`, `/admin/dashboard`, `/admin/accounts`, `/teacher`, `/parent`, `/student`, or `/dashboard`; `/profile` and auth/recovery routes remain outside the guard.

## Before any live authentication or data

An approved Supabase project, credentials, privacy/legal and retention decisions, identity/invitation workflow, stakeholder workflow decisions, fuller RLS test coverage, and staging/backup procedures are still required. Do not add real pupils, staff, guardians, or production exports to local seed data.
