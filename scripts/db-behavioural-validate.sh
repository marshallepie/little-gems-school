#!/usr/bin/env bash
# Behavioural database validation: migrations + RLS, against a live local stack.
#
# Run on the VPS host as root, outside the agent container. The hermes-agent
# container deliberately has no Docker daemon, no host socket and no psql, so
# this cannot run from inside the agent -- see supabase/LOCAL-VALIDATION.md.
#
# This is the executable form of the sequence in supabase/tests/README.md.
# It is NOT interchangeable with /usr/local/bin/lgs-db-validate: that helper
# does a plain `supabase db reset`, which applies the whole migration chain
# onto an empty database. Since 20260831010000_administrative_authorization_
# cutover.sql that always fails closed, because the reviewed proprietor
# mapping does not exist on a bare reset. The sequence below seeds the gate
# fixture between resets, so the cutover migration can apply.
#
# Ports 54321-54329 bind 0.0.0.0 and the host firewall is inactive, so the
# stack is always stopped again before this script exits.

set -uo pipefail

PROJECT_DIR=${PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
SUPABASE=${SUPABASE_CMD:-"npx --yes supabase@2.114.0"}
# Container name is supabase_db_<project_id> from supabase/config.toml.
DB=${SUPABASE_DB_CONTAINER:-supabase_db_little-gems-school}
OWNER=${HERMES_OWNER:-10000:10000}

cleanup() {
  echo
  echo "==> cleanup: stopping stack, restoring hermes ownership"
  (cd "$PROJECT_DIR" && $SUPABASE stop >/dev/null 2>&1) || true
  [ "$(id -u)" = 0 ] && chown -R "$OWNER" "$PROJECT_DIR/supabase" 2>/dev/null
  return 0
}
trap cleanup EXIT

cd "$PROJECT_DIR" || exit 1

run() {
  echo
  echo "########## STEP: $* ##########"
  if ! "$@"; then
    echo "########## FAILED: $* ##########"
    exit 1
  fi
}

# The test scripts use psql meta-commands (\echo) and must run through psql.
# `supabase db query` sends the file to the server as plain SQL and fails with
# `syntax error at or near "\"`. ON_ERROR_STOP makes a raised exception fatal.
q() {
  echo
  echo "########## TEST: $1 ##########"
  if ! docker exec -i "$DB" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -f - < "supabase/tests/$1"; then
    echo "########## FAILED: $1 ##########"
    exit 1
  fi
}

run $SUPABASE start

# --no-seed is required, not optional: seed.sql inserts a teacher with no
# profile_id, and that column is only made nullable by 20260829000000, so
# seeding here aborts on a not-null violation. foundation_historical_role_seed
# also asserts public.roles is empty, which seeding would violate.
run $SUPABASE db reset --no-seed --version 20260827000000
q foundation_historical_role_seed.sql

# Reset to the pre-cutover baseline and exercise the RLS suites that must hold
# before authorization cuts over. Seed data is wanted from here on.
run $SUPABASE db reset --version 20260831000000
q teachers_rls.sql
q phase1_identity_rls.sql

# Establishes the reviewed three-account fixture the cutover gate requires.
q administrative_authorization_cutover_gate.sql

# Applies the cutover and every later migration against that fixture.
run $SUPABASE migration up --local
q administrative_authorization.sql
q account_lifecycle_and_profiles.sql
q server_only_authorization_workflows.sql
q phase3_operations_rls.sql
q public_admissions_rls.sql

echo
echo "OK: all behavioural database tests completed."
