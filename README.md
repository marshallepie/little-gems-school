# Little Gems School — Phase 1 identity and school structure

This repository contains the approved **Native Next.js + Supabase foundation plus Phase 1 identity and school structure**: Supabase email/password and reset flows, role-route shells, an admin-only mobile-first record-management surface, SSR Supabase client/proxy wiring, and relationship-oriented schema/RLS. It intentionally does not implement Phase 2 dashboards or Phase 3 operations, CMS, storage, payments, communications, cloud provisioning, or real accounts/data.

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

Run the application and its foundation quality gates:

```bash
npm run dev
npm run test
npm run typecheck
npm run lint
npm run build
```

Without the two public environment variables, public/auth pages remain usable and `/dashboard` fails safely by routing to login. Configure local Supabase before testing the real email/password and password-reset flows. Initial accounts and role assignments remain an approved administrative provisioning workflow; the browser never receives a service-role key.

## Security boundary

`auth.users` remains Supabase-owned. App roles are normalized in `roles`/`user_roles`, not JWT metadata. Server checks use `auth.getClaims()` rather than authorizing from `getSession()`; `proxy.ts` refreshes session cookies. UI redirects are only UX—the database uses RLS with default deny and private `app_private` helper functions as the enforcement boundary.

## Before any live authentication or data

An approved Supabase project, credentials, privacy/legal and retention decisions, identity/invitation workflow, stakeholder workflow decisions, fuller RLS test coverage, and staging/backup procedures are still required. Do not add real pupils, staff, guardians, or production exports to local seed data.
