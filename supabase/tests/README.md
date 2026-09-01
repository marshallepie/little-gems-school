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
cd /opt/data/profiles/mepa-v2/projects/little-gems-school
set -e
trap 'supabase stop' EXIT
supabase start
supabase db reset --version 20260827000000
npx --yes supabase@2.114.0 db query --local --file supabase/tests/foundation_historical_role_seed.sql
supabase db reset --version 20260831000000
npx --yes supabase@2.114.0 db query --local --file supabase/tests/teachers_rls.sql
npx --yes supabase@2.114.0 db query --local --file supabase/tests/phase1_identity_rls.sql
npx --yes supabase@2.114.0 db query --local --file supabase/tests/administrative_authorization_cutover_gate.sql
supabase migration up --local
npx --yes supabase@2.114.0 db query --local --file supabase/tests/administrative_authorization.sql
npx --yes supabase@2.114.0 db query --local --file supabase/tests/account_lifecycle_and_profiles.sql
npx --yes supabase@2.114.0 db query --local --file supabase/tests/server_only_authorization_workflows.sql
```

Expected final authorization output:

```text
PASS: administrative authorization cutover gate tests
PASS: administrative authorization hierarchy behavioural tests
PASS: account lifecycle and self-profile behavioural tests
PASS: server-only authorization workflow behavioural tests
```

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

`/usr/local/bin/lgs-db-validate` remains the standard reset/reporting helper,
but it stops the stack when it exits and does not execute custom behavioural SQL.
Use the explicit sequence above when validating this test.
