export type LifecycleOperation = () => Promise<{ error: { message: string } | null }>;

export type AuthBanAttemptResult =
  | { completed: true }
  | { completed: false; error: string };

/**
 * Complete the external half of the deprovision saga. The database deprovision
 * RPC has already revoked authorization and written `auth_ban_state = pending`.
 * Completion is deliberately durable only after Auth confirms the ban and the
 * completion RPC persists that fact. Retrying this operation is safe.
 */
export async function completePendingAuthBan({
  banAuthUser,
  markFailure,
  markCompleted,
}: {
  banAuthUser: LifecycleOperation;
  markFailure: LifecycleOperation;
  markCompleted: LifecycleOperation;
}): Promise<AuthBanAttemptResult> {
  const { error: banError } = await banAuthUser();
  if (banError) {
    const { error: failureStateError } = await markFailure();
    if (failureStateError) {
      return { completed: false, error: "Auth ban failed and its recovery state could not be updated. The account remains database-deprovisioned; retry the Auth ban after operator review." };
    }
    return { completed: false, error: "Auth ban failed. The account remains database-deprovisioned and is marked for an operator retry." };
  }

  const { error: completionStateError } = await markCompleted();
  if (completionStateError) {
    return { completed: false, error: "Auth ban was accepted, but durable completion could not be recorded. Retry the Auth ban to complete lifecycle recovery." };
  }
  return { completed: true };
}
