# Administrative authorization and initial-production bootstrap

## Permission hierarchy

| Tier | Position | Permissions |
| --- | --- | --- |
| 1 | `proprietor_super_admin` | `authorization.manage`, `people.manage`, `academic_structure.manage`, `enrolments.manage`, `teacher_assignments.manage`, `school_records.read` |
| 2 | `senior_administrator` | `people.manage`, `academic_structure.manage`, `enrolments.manage`, `teacher_assignments.manage`, `school_records.read` |
| 3 | `headmistress` | `academic_structure.manage`, `enrolments.manage`, `teacher_assignments.manage`, `school_records.read` |

Portal roles remain `admin`, `teacher`, `parent`, and `student`. An `admin` without
an active position is denied administrative access. The policy cutover fails closed
until every active normalized admin has exactly one active position.

## Approved one-time production mapping

This procedure is authorized **only** for a fresh production Supabase project with
zero Auth users and empty migration history. It creates no invitations and sends no
email. The operator must verify the intended recipients independently before
starting and map only these accounts:

| Approved email (displayed exactly) | Position |
| --- | --- |
| `AdrianAnyata@marshallepie.com` | `proprietor_super_admin` |
| `R.Oses@marshallepie.com` | `senior_administrator` |
| `G.I.Ucheya@marshallepie.com` | `headmistress` |

Supabase may canonicalize email case; the database comparison is case-insensitive,
but the three values above are the authorization record. The initial accounts are
confirmed password accounts: Marshall gives each temporary password only through
the approved secure channel. Each user completes their basic profile and changes
the password at first login. Passwords, service keys, UUIDs, tokens, and screenshots
containing them must never enter this repository, shell history, tickets, chat, or
logs.

## Production runbook — operator only

**Do not run this against local, staging, or a non-empty/shared project. Do not use
a browser, browser environment variable, or client bundle for the service-role key.**
Use a restricted server/operator terminal with a short-lived secret injection method
that does not print commands (for example, an approved secret manager). Do not put
passwords on a command line or in environment variables.

### 1. Preflight and first migration pass

1. Confirm the Supabase project reference/URL with a second operator and take a
   backup/change record. Confirm `Authentication > Users` has **zero** users and
   that the remote migration history is empty. If either is false, stop: this
   one-time procedure is inapplicable and requires an incident/change review.
2. Link the CLI to the exact production project and run the normal ordered migration
   deployment:
   ```sh
   supabase db push
   ```
   It must stop at `20260831010000_administrative_authorization_cutover.sql` with
   the documented fail-closed proprietor-mapping error. This is expected: earlier
   migrations, including the private one-time function, are now installed. Do not
   edit migration history, mark a failed migration as applied, or bypass this gate.

### 2. Create exactly the three Auth identities (server-side service role)

From the repository root on the restricted server, inject only `SUPABASE_URL` and
`SUPABASE_SERVICE_ROLE_KEY` into that process/session. The key must not be
`NEXT_PUBLIC_*`, placed in `.env*`, passed to Node as an argument, or exposed to a
browser. The executable prompts twice for each password with terminal echo disabled,
requires 20+ characters with upper/lower/number/symbol, confirms each identity, and
sets `email_confirm: true`; `auth.admin.createUser` sends no email in this flow.

```sh
LGS_INITIAL_BOOTSTRAP_CONFIRM=CREATE-EXACTLY-THREE \
node scripts/bootstrap-initial-production-auth.mjs
```

The script refuses unless the target has zero Auth users both during its initial
preflight **and again after every hidden password prompt/confirmation, immediately
before its first `createUser` call**. It rejects an incomplete or ambiguous
paginated Auth-user listing rather than treating it as empty. This final check
reduces, but cannot eliminate, the Admin API race between inspection and creation:
if it fails, stop and use the forward-only failure gate. It prints only the created
Auth UUID/email (not passwords) so the operator can reconcile identities. It does
**not** persist passwords. Marshal the temporary passwords directly to the three
recipients using the approved secure channel, then dispose of the operator's
transient notes.

**Forward-only failure gate:** if creation stops after one or two users, do not
rerun the script and do not delete/alter Auth rows casually. Record the returned
UUID/email and stop the cutover. An authorized database/security operator must
reconcile the exact existing set and either complete a reviewed recovery or restore
the pre-change state before any migration resumes. The SQL step below requires
exactly three users and will refuse a partial or extra-user state.

### 3. Independently verify and atomically map identities

A database operator connected as `postgres` or `supabase_admin` (not an application
JWT and not a service-role RPC) must independently inspect `auth.users` and confirm
there are exactly these three confirmed, unbanned identities and no others. Do not
copy UUIDs into SQL. Then execute exactly this transaction in the restricted SQL
operator session:

```sql
begin;
select app_private.bootstrap_initial_production_administrators();
commit;
```

The function has no user-supplied identity argument. In one transaction it: verifies
the exact three-account invariant; rejects pre-existing roles/positions; repairs a
missing profile caused by a pre-trigger/existing Auth user; sets active profiles'
`default_role_code = 'admin'`; assigns the normalized `admin` role; creates the
three approved positions; and writes private identity/position verification rows
without any password or Auth metadata. It writes a singleton completion invariant,
so a second execution fails. Application roles, `service_role`, anonymous callers,
and authenticated browser callers have no execute grant.

Before continuing, query and independently reconcile the result (UUIDs may be
shown only in the restricted operator result):

```sql
select v.approved_email, v.position_code, v.verified_at, v.verified_by,
       p.default_role_code, p.is_active, u.email, u.email_confirmed_at,
       u.banned_until
from app_private.initial_production_bootstrap_verifications v
join public.profiles p on p.id = v.user_id
join auth.users u on u.id = v.user_id
order by v.position_code;

select position_code, count(*)
from public.admin_position_assignments
where revoked_at is null
group by position_code
order by position_code;
```

Expected: three verification rows, three active `admin` profiles/roles, and one row
for each listed position. Any mismatch is a stop condition. Do not patch mappings
manually or loosen RLS; preserve evidence, diagnose in a new authorized change, and
use backup/restore only under the approved production recovery process.

### 4. Cut over and retire bootstrap capability

Only after both operators approve the reconciliation, resume the same ordered path:

```sh
supabase db push
```

The cutover gate reruns and succeeds only with the required mappings. The final
migration drops `app_private.bootstrap_initial_production_administrators()` so no
reusable privilege-escalation bootstrap capability remains; private verification
rows remain audit evidence. Verify it is gone and the final migration is recorded:

```sql
select to_regprocedure('app_private.bootstrap_initial_production_administrators()') is null as bootstrap_retired;
```

If this final deployment fails, stop. Do not roll back migrations or re-run the
bootstrap function; remediate forward in a reviewed migration or use the approved
restore procedure. Standard account/position changes after this point use the
proprietor-authorized server workflows, never this initial bootstrap.

## Validation coverage

`supabase/tests/administrative_authorization_cutover_gate.sql` verifies: empty
history fails closed; missing identities cannot run the one-time bootstrap; the
successful exact three-account bootstrap repairs/makes profiles, normalized roles,
positions, private verification records, and the cutover gate; and a second attempt
is rejected. Run the disposable local sequence in `supabase/tests/README.md`; never
run those deterministic Auth fixtures against a remote project.
