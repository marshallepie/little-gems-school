-- Run after `supabase db reset --version 20260827000000`.
-- This represents a remote where foundation is already recorded from before
-- portal-role seeding. The initial bootstrap function is intentionally absent;
-- only 20260831000000 can add both the roles and that capability.
do $$
begin
  if to_regprocedure('app_private.bootstrap_initial_production_administrators()') is not null then
    raise exception 'foundation-only history unexpectedly exposes initial bootstrap';
  end if;
  if exists (select 1 from public.roles) then
    raise exception 'foundation-only history unexpectedly contains seeded portal roles';
  end if;
end;
$$;
\echo 'PASS: historical foundation migration has no portal-role seed or bootstrap capability'
