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

export type ReprovisionLifecycleState = "inactive" | "active" | "unknown";
export type ReprovisionSagaResult =
  | { completed: true }
  | { completed: false; reconciliationRequired: boolean; error: string };

/**
 * Coordinate the Auth-unban and database-activation halves of re-provisioning.
 * An activation error is ambiguous: it may mean the RPC was not applied, or that
 * its response was lost after it activated the profile. Re-ban only after a
 * repeated read confirms the profile remains inactive; never infer inactivity
 * from a failed/missing read.
 */
export async function completeReprovisionSaga({
  resetPasswordAndUnban,
  activateDatabase,
  readLifecycleState,
  rebanAuthUser,
  recordReconciliationNeeded,
  lifecycleReadAttempts = 3,
}: {
  resetPasswordAndUnban: LifecycleOperation;
  activateDatabase: LifecycleOperation;
  readLifecycleState: () => Promise<ReprovisionLifecycleState>;
  rebanAuthUser: LifecycleOperation;
  recordReconciliationNeeded: LifecycleOperation;
  lifecycleReadAttempts?: number;
}): Promise<ReprovisionSagaResult> {
  const { error: authError } = await resetPasswordAndUnban();
  if (authError) {
    return { completed: false, reconciliationRequired: false, error: "Unable to reset the temporary password and remove the Auth ban. The account remains deprovisioned." };
  }

  const { error: activationError } = await activateDatabase();
  if (!activationError) return { completed: true };

  for (let attempt = 0; attempt < lifecycleReadAttempts; attempt += 1) {
    const lifecycleState = await readLifecycleState();
    if (lifecycleState === "active") {
      const { error: auditError } = await recordReconciliationNeeded();
      return {
        completed: false,
        reconciliationRequired: true,
        error: auditError
          ? "Re-provisioning returned an error after the Auth identity was unbanned, but the database account is active. Do not retry or re-ban; operator review is required, and the reconciliation audit record could not be persisted."
          : "Re-provisioning returned an error after the Auth identity was unbanned, but the database account is active. Do not retry or re-ban; operator review is required.",
      };
    }
    if (lifecycleState === "inactive") {
      const { error: rebanError } = await rebanAuthUser();
      if (rebanError) {
        const { error: auditError } = await recordReconciliationNeeded();
        return {
          completed: false,
          reconciliationRequired: true,
          error: auditError
            ? "Re-provisioning failed and the Auth identity could not be re-banned. The account remains database-deprovisioned; operator review is required, and the reconciliation audit record could not be persisted."
            : "Re-provisioning failed and the Auth identity could not be re-banned. The account remains database-deprovisioned; operator review is required.",
        };
      }
      return { completed: false, reconciliationRequired: false, error: "Re-provisioning was not completed. The Auth identity was re-banned after the database account was confirmed inactive." };
    }
  }

  const { error: auditError } = await recordReconciliationNeeded();
  return {
    completed: false,
    reconciliationRequired: true,
    error: auditError
      ? "Re-provisioning returned an error and the database lifecycle state could not be reconciled. The Auth identity was not re-banned; operator reconciliation is required, and the reconciliation audit record could not be persisted."
      : "Re-provisioning returned an error and the database lifecycle state could not be reconciled. The Auth identity was not re-banned; operator reconciliation is required.",
  };
}
