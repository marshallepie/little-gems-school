# Database behavioural tests

## `teachers_rls.sql`

This is a **behavioural** RLS test: it seeds five deterministic auth identities
(Admin, Teacher A, Teacher B, Parent, Student), switches to `authenticated` or
`anon` with a request JWT subject, and executes real SELECT/INSERT/UPDATE/DELETE
statements. It never runs assertions as a table owner or service role. The
script wraps its fixtures in a transaction and rolls them back, so it is safe to
run repeatedly after a reset.

Run the complete clean validation on the VPS host (as root, outside the agent
container). The trap always stops the locally exposed stack:

```sh
cd /opt/data/profiles/mepa-v2/projects/little-gems-school
set -e
trap 'supabase stop' EXIT
supabase start
supabase db reset
npx --yes supabase@2.114.0 db query --local --file supabase/tests/teachers_rls.sql
```

Expected final test output:

```text
PASS: public.teachers behavioural RLS tests
```

`/usr/local/bin/lgs-db-validate` remains the standard reset/reporting helper,
but it stops the stack when it exits and does not execute custom behavioural SQL.
Use the explicit sequence above when validating this test.
