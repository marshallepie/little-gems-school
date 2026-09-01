-- Retire the operator-only initial-bootstrap capability after the successful
-- fail-closed cutover. The private verification/state rows remain as evidence, but
-- no callable bootstrap path survives for later production use.
select app_private.assert_administrative_authorization_ready();
drop function app_private.bootstrap_initial_production_administrators();
