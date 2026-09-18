-- Forward-only privilege repair for the disposable-account purge saga. Function
-- creation grants EXECUTE to PUBLIC by default, so revoke it explicitly from
-- every browser-facing role before retaining only the trusted server capability.
revoke execute on function
  public.classify_disposable_test_account_from_server(uuid, uuid),
  public.begin_disposable_account_purge_from_server(uuid, uuid),
  public.record_disposable_account_purge_auth_failed_from_server(uuid, uuid),
  public.record_disposable_account_purge_auth_verification_failed_from_server(uuid, uuid)
from public, anon, authenticated;

grant execute on function
  public.classify_disposable_test_account_from_server(uuid, uuid),
  public.begin_disposable_account_purge_from_server(uuid, uuid),
  public.record_disposable_account_purge_auth_failed_from_server(uuid, uuid),
  public.record_disposable_account_purge_auth_verification_failed_from_server(uuid, uuid)
to service_role;
