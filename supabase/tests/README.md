# Database behavioural tests

## `teachers_rls.sql`, `phase1_identity_rls.sql`, and administrative authorization

These are **behavioural** RLS tests: they use deterministic local-only Auth
fixtures, switch to `authenticated` or `anon` with a request JWT subject, and
execute real SQL statements. They never assert as a table owner or service role.
The authorization sequence proves the actual cutover gate rejects an empty
baseline, the one-time bootstrap rejects missing identities, and only the reviewed
three-account fixture set can establish the required profiles, normalized roles,
positions, and private verification evidence before cutover.

Run only against a disposable local stack on the VPS host (as root, outside the
agent container). The commands stop the locally exposed stack on exit:

```sh
cd /docker/hermes-agent-vxsl/data/profiles/mepa-v2/projects/little-gems-school
scripts/db-behavioural-validate.sh
```

Two details in that script are load-bearing, so do not "simplify" them back:

- **`--no-seed` on the foundation reset.** `seed.sql` inserts a teacher with no
  `profile_id`, and `20260829000000` is what makes that column nullable, so
  seeding at `20260827000000` aborts on a not-null violation. The very next
  test also asserts `public.roles` is empty, which seeding would violate.
- **Tests run through `psql`, not `supabase db query`.** They use `\echo`, a
  psql meta-command; sent to the server as plain SQL it fails with
  `syntax error at or near "\"`. The script pipes each file into
  `docker exec -i supabase_db_little-gems-school psql ... -v ON_ERROR_STOP=1`.

The equivalent steps, if you ever need to run them by hand:

```sh
SUPABASE="npx --yes supabase@2.114.0"
PSQL="docker exec -i supabase_db_little-gems-school psql -U postgres -d postgres -v ON_ERROR_STOP=1 -f -"
$SUPABASE start
$SUPABASE db reset --no-seed --version 20260827000000
$PSQL < supabase/tests/foundation_historical_role_seed.sql
$SUPABASE db reset --version 20260831000000
$PSQL < supabase/tests/teachers_rls.sql
$PSQL < supabase/tests/phase1_identity_rls.sql
$PSQL < supabase/tests/administrative_authorization_cutover_gate.sql
$SUPABASE migration up --local
$PSQL < supabase/tests/administrative_authorization.sql
$PSQL < supabase/tests/account_lifecycle_and_profiles.sql
$PSQL < supabase/tests/server_only_authorization_workflows.sql
$PSQL < supabase/tests/phase3_operations_rls.sql
$SUPABASE stop
```

Expected final authorization output:

```text
PASS: administrative authorization cutover gate tests
PASS: administrative authorization hierarchy behavioural tests
PASS: account lifecycle and self-profile behavioural tests
PASS: server-only authorization workflow behavioural tests
```

## Open blockers (as of 2026-09-04)

The harness above now runs. Two defects in the code under test still stop the
suite before it reaches `phase3_operations_rls.sql`, so Phase 3 has no database
evidence yet. First host-side run to get this far reached:

```text
PASS: historical foundation migration has no portal-role seed or bootstrap capability
PASS: public.teachers behavioural RLS tests
PASS: Phase 1 integrity and relationship RLS tests
PASS: administrative authorization cutover gate tests
PASS: administrative authorization hierarchy behavioural tests
```

**1. The migration chain cannot apply to a fresh database.**
`20260901000000_phase3_operations_authorization.sql` creates
`app_private.can_access_document`, a `language sql` function that selects from
`public.documents` and `public.document_targets`. Both tables are first created
by the *next* migration, `20260901010000_phase3_operations_schema.sql`. Postgres
validates SQL function bodies at creation, so `migration up` aborts with
`relation "public.documents" does not exist (SQLSTATE 42P01)`.

This is not only a test problem: it would break a deploy onto a clean database.
Every other function in that migration references tables that already exist, so
the fix is confined to `can_access_document` — create it after the tables exist.
These migrations have never applied anywhere, so amending them in place does not
violate the append-only rule.

**2. `account_lifecycle_and_profiles.sql` cannot pass as written.**
After `select public.provision_portal_account(...)` it verifies the result while
still `set local role authenticated` as the proprietor. Its own migration,
`20260831020000_account_lifecycle_and_profiles.sql`, defines `profiles_self_read`
as `using (id = (select auth.uid()))` — self only. The proprietor therefore
cannot see the provisioned user's row, and the block raises
`provision did not activate default role` even though provisioning succeeded.
The assertions need to run after `reset role`.

The gate fixture persists only in the disposable stack so the subsequent local
cutover can exercise the same migration-history sequence as production. The first
reset proves an already-recorded foundation migration has neither a portal-role
seed nor bootstrap capability; the forward administrative-authorization migration
then supplies the roles before the bootstrap test can succeed. The hierarchy test
rolls back its additional unpositioned-admin fixture. Never run these fixtures
against a shared or remote project. The account lifecycle script also proves a
direct authenticated profile update cannot bypass the exact
`https://` avatar constraint, an active second `proprietor_super_admin` cannot
be deprovisioned, and a failed Auth-ban state remains database-deprovisioned
until a proprietor records a successful retry.

`scripts/db-behavioural-validate.sh` is the executable form of the sequence
above; prefer it over running the steps by hand.

`/usr/local/bin/lgs-db-validate` does not execute custom behavioural SQL, and
its plain `supabase db reset` now fails closed at the authorization cutover
migration because a bare reset has no reviewed proprietor mapping. Use it only
for its schema/policy-count report, never as migration validation.
