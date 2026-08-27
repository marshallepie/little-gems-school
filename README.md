# Little Gems School — Phase 0 foundation

This repository contains the approved **Native Next.js + Supabase foundation only**: a public landing page, safe authentication placeholders, role-route shells, SSR Supabase client/proxy wiring, and a relationship-oriented baseline schema with RLS. It intentionally does not implement school operations, CMS, storage, payments, communications, cloud provisioning, or real accounts/data.

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

Without the two public environment variables, public/auth pages remain usable and `/dashboard` fails safely by routing to login; configure local Supabase before testing real auth flows.

## Security boundary

`auth.users` remains Supabase-owned. App roles are normalized in `roles`/`user_roles`, not JWT metadata. Server checks use `auth.getClaims()` rather than authorizing from `getSession()`; `proxy.ts` refreshes session cookies. UI redirects are only UX—the database uses RLS with default deny and private `app_private` helper functions as the enforcement boundary.

## Before any live authentication or data

An approved Supabase project, credentials, privacy/legal and retention decisions, identity/invitation workflow, stakeholder workflow decisions, fuller RLS test coverage, and staging/backup procedures are still required. Do not add real pupils, staff, guardians, or production exports to local seed data.
