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

The baseline was validated on 2026-08-28 against Supabase CLI 2.114.0 / postgres 17.6.1.158. This Phase 1 migration and expanded fixture set require a fresh host-side run before a deployment because the agent container intentionally has no Docker daemon.

Run `/usr/local/bin/lgs-db-validate`, then execute both scripts documented in `supabase/tests/README.md`. That validates the append-only migration chain, Phase 1 seed fixtures, existing teacher RLS, and Phase 1 relationship/integrity checks.

## Known environment limitations

- `imgproxy` and `pooler` do not start (disabled in `config.toml`); harmless for migration/seed validation.

## Safety note

The local stack binds all services to `0.0.0.0`, uses well-known default
credentials, and leaves Studio / pgMeta unauthenticated. The host firewall is
currently **inactive** (`ufw` inactive, iptables `INPUT ACCEPT`), so while the
stack is up, ports 54321-54329 are reachable from the internet. Never leave it
running; the script handles this by always stopping on exit.
