---
name: run-app
description: Launch and drive the Little Gems School app locally — starts Docker, the local Supabase stack, and the Next.js dev server, provisions a local test admin, and drives login plus admin record creation in a real browser. Use when asked to run, start, or screenshot the app, or to confirm a change works end to end.
---

# Run the Little Gems School app

Verified path. Follow it in order; each step depends on the previous one.

Verified with Node 22.22.3, Next 16.3.3, Supabase CLI via `npx`, on macOS.

## 1. Install dependencies

```bash
npm install
```

## 2. Start Docker

Supabase local needs the Docker daemon. On macOS it is usually not running:

```bash
docker info >/dev/null 2>&1 || open -a Docker
until docker info >/dev/null 2>&1; do sleep 2; done; echo "DOCKER READY"
```

`open -a Docker` may need the sandbox disabled.

## 3. Start Supabase

```bash
npx supabase start
```

**Expect the first run to fail.** While it is still pulling images, the health
check times out:

```
{"_tag":"Error","error":{"code":"LegacyHealthCheckTimeoutError","message":"supabase_analytics_... is not ready: unhealthy ..."}}
```

This is not a real failure and needs no config change. The images are cached by
then, so **just run `npx supabase start` again** and it succeeds. Migrations and
`supabase/seed.sql` apply automatically.

## 4. Write `.env.local`

Read the keys from the running stack rather than pasting them — they are
credentials, and hardcoding them here would commit them:

```bash
npx supabase status -o json > /tmp/lgs-status.json
node -e '
const s = require("/tmp/lgs-status.json");
require("fs").writeFileSync(".env.local",
  `NEXT_PUBLIC_SUPABASE_URL=${s.API_URL}\nNEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=${s.PUBLISHABLE_KEY}\n`);
'
```

Only `PUBLISHABLE_KEY` belongs in a `NEXT_PUBLIC_*` var. `SECRET_KEY` is for
step 6 (server side, shell only) and must never reach the browser or a commit.

## 5. Start the dev server

```bash
npm run dev > /tmp/lgs-dev.log 2>&1 &
```

**Check the log for the actual port** — if 3000 is taken, Next silently falls
back to 3001 and every later URL must match:

```bash
grep -E "Local:|Ready in" /tmp/lgs-dev.log
```

Keep this log. Server Component and Server Action errors surface *here*, not in
the browser console.

Next 16 also writes untracked `AGENTS.md` and `CLAUDE.md` on first `dev`. Harmless;
set `agentRules: false` in `next.config.ts` to stop it.

## 6. Provision a local test admin

`supabase/seed.sql` deliberately contains **no auth users** — account
provisioning is an administrative workflow. So nothing can log in until you
create a user. Local only, fictional, never real data:

```bash
SECRET=$(node -e 'console.log(require("/tmp/lgs-status.json").SECRET_KEY)')
USER_ID=$(curl -s -X POST 'http://127.0.0.1:54321/auth/v1/admin/users' \
  -H "apikey: $SECRET" -H "Authorization: Bearer $SECRET" \
  -H 'Content-Type: application/json' \
  -d '{"email":"admin@local.test","password":"LocalTest123!","email_confirm":true}' \
  | node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>console.log(JSON.parse(d).id))')

docker exec supabase_db_little-gems-school psql -U postgres -d postgres \
  -c "insert into public.user_roles (user_id, role_id)
      select '$USER_ID', id from public.roles where code='admin' on conflict do nothing;" \
  -c "update public.profiles set default_role_code='admin' where id='$USER_ID';"
```

A trigger creates the `profiles` row from `auth.users`, but with a null
`default_role_code`. Both the `user_roles` insert **and** the `default_role_code`
update are required: `requireRole()` checks the profile's default role *and*
that the role is actually assigned.

Clean up with `npx supabase db reset`, which also restores the seed.

## 7. Drive it in a browser

Playwright is not a project dependency:

```bash
npm install --no-save playwright && npx playwright install chromium
```

The driver must run **from the project root** — an ESM script in `/tmp` cannot
resolve `playwright` from the project's `node_modules`:

```bash
cp .claude/skills/run-app/drive.mjs ./drive.mjs
BASE_URL=http://localhost:3001 node ./drive.mjs
rm ./drive.mjs
```

`drive.mjs` covers landing page, signed-out redirect enforcement, a rejected
bad password, a successful login through to the admin surface, and creating a
student record. It writes screenshots to `/tmp/lgs-*.png` — **look at them**; a
blank or error-overlay frame is a failure even when the script exits 0.

### Gotcha: the form clears after a failed submit

`components/auth-form.tsx` uses a React form action, so a rejected login resets
**both** fields. Refill email *and* password for the second attempt, or the
browser's own `required` validation silently blocks the submit and the app looks
broken when it is fine.

## 8. Quality gates

```bash
npm run typecheck && npm run lint && npm test
```

## Reading failures

Protected routes rendering "This page couldn't load" means a Server Component
threw — `grep -A15 TypeError /tmp/lgs-dev.log`. A 400 in the browser console
during the deliberate bad-login step is expected: Supabase returns 400 for
invalid credentials.

When touching PostgREST embeds, note that `user_roles → roles` is **many-to-one**,
so `select("roles!inner(code)")` returns a single **object**, not an array.
Assuming an array there is what broke `requireRole()` and every admin write
action.
