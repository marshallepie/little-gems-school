# Local Supabase validation

## Why this file exists

The agent runtime (`hermes-agent` container) has the Docker **CLI** but no Docker
**daemon**, and deliberately does not get the host socket: that container is
published through Traefik, so mounting `/var/run/docker.sock` into it would give
a publicly-reachable service root-equivalent control of the host.

So `npx supabase start` cannot run inside the agent container. This is a
deliberate design decision, not an unresolved blocker. Local database validation
runs **host-side** instead.

## How to validate

On the VPS host (as root, not inside the agent container):

```
/usr/local/bin/lgs-db-validate
```

That script is idempotent and always stops the stack again on exit. It runs:

1. `supabase start`
2. `supabase db reset` — applies `supabase/migrations/*.sql`, then `supabase/seed.sql`
3. schema / RLS / policy-count report
4. a check for tables with RLS enabled but **no** policy (deny-all)
5. seed row counts
6. `supabase status`
7. `supabase stop` + restores `hermes` (uid 10000) ownership of `supabase/`

## Last validated

2026-08-28, against Supabase CLI 2.114.0 / postgres 17.6.1.158.

- `20260827000000_foundation.sql` applied cleanly from an empty database.
- `seed.sql` applied cleanly: 4 roles, 1 academic year, 1 term, 2 class groups, 2 subjects.
  The seed contains reference data only — no `profiles`, `students`, `teachers`,
  or `guardians` rows, since those depend on `auth.users`.
- 13 tables in `public`, all with RLS enabled, 14 policies total.

## Known issues found during validation

- **`public.teachers` has RLS enabled but zero policies**, so it is deny-all for
  the `authenticated` role. Every other table has at least one SELECT policy.
  If teacher records are meant to be readable, the baseline migration is missing
  a `teachers` policy.
- `imgproxy` and `pooler` do not start (disabled in `config.toml`); harmless for
  migration/seed validation.

## Safety note

The local stack binds all services to `0.0.0.0`, uses well-known default
credentials, and leaves Studio / pgMeta unauthenticated. The host firewall is
currently **inactive** (`ufw` inactive, iptables `INPUT ACCEPT`), so while the
stack is up, ports 54321-54329 are reachable from the internet. Never leave it
running; the script handles this by always stopping on exit.
