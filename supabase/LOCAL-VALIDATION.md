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
scripts/db-behavioural-validate.sh
```

That is the executable form of the sequence in `supabase/tests/README.md`. It
is idempotent, always stops the stack again on exit, and restores `hermes`
(uid 10000) ownership of `supabase/`. It applies the migration chain, seeds the
authorization cutover fixture, and runs every behavioural RLS suite including
`phase3_operations_rls.sql`.

### Do not use `lgs-db-validate` for migration validation

`/usr/local/bin/lgs-db-validate` does a plain `supabase db reset`, which applies
the whole chain onto an empty database. Since
`20260831010000_administrative_authorization_cutover.sql` landed, that **always
fails closed**:

```
ERROR: authorization cutover blocked: active proprietor_super_admin mapping for
verified <proprietor> is required (SQLSTATE P0001)
```

That is the gate working as designed, not a regression: a bare reset has no
reviewed proprietor mapping, so the cutover correctly refuses. The helper is
still useful for its schema / RLS / policy-count report, but only against a
database the behavioural script has already brought up to head.

It runs:

1. `supabase start`
2. `supabase db reset` — applies `supabase/migrations/*.sql`, then `supabase/seed.sql`
3. schema / RLS / policy-count report
4. a check for tables with RLS enabled but **no** policy (deny-all)
5. seed row counts
6. `supabase status`
7. `supabase stop` + restores `hermes` (uid 10000) ownership of `supabase/`

## Last validated

The baseline was validated on 2026-08-28 against Supabase CLI 2.114.0 / postgres 17.6.1.158. This Phase 1 migration and expanded fixture set require a fresh host-side run before a deployment because the agent container intentionally has no Docker daemon.

Run `scripts/db-behavioural-validate.sh`. That validates the append-only migration chain, the authorization cutover gate, seed fixtures, teacher RLS, Phase 1 relationship/integrity checks, and the Phase 3 operations RLS suite.

**Phase 3 is not validated.** A host-side run on 2026-09-04 got the harness
working and passed five suites, then stopped on two defects in the code under
test — a forward reference to `public.documents` that prevents the migration
chain applying to a fresh database, and an assertion in
`account_lifecycle_and_profiles.sql` that runs under an RLS policy which hides
the rows it checks. Both are described in `supabase/tests/README.md`. The
Phase 3 RLS suite has still never executed.

## Known environment limitations

- `imgproxy` and `pooler` do not start (disabled in `config.toml`); harmless for migration/seed validation.

## Safety note

The local stack binds all services to `0.0.0.0`, uses well-known default
credentials, and leaves Studio / pgMeta unauthenticated. The host firewall is
otherwise **inactive** (`ufw` inactive, iptables `INPUT ACCEPT`), so while the
stack is up, ports 54321-54329 would be reachable from the internet. Never leave
it running; the script handles this by always stopping on exit.

Targeted DROP rules for those ports were added to the host on 2026-09-04. They
are **not persistent**, so re-add them after a reboot before validating:

```sh
iptables  -t raw -I PREROUTING 1 -i eth0 -p tcp --dport 54321:54329 -j DROP
ip6tables -t raw -I PREROUTING 1 -i eth0 -p tcp --dport 54321:54329 -j DROP
```

They must go in the `raw` table, before DNAT. A rule in `INPUT` does nothing
here: Docker-published ports are DNAT'd in `PREROUTING` and traverse `FORWARD`,
so they never reach `INPUT`. Matching in `raw/PREROUTING` also runs before the
port translation, so the original host port still matches. Loopback arrives on
`lo` and container traffic on the bridges, so neither is affected. Check with
`iptables -t raw -S PREROUTING | grep 5432`; swap `-I PREROUTING 1` for
`-D PREROUTING` to remove.
