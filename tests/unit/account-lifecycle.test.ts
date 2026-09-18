import { describe, expect, it, vi } from "vitest";
import { completePendingAuthBan, completeReprovisionSaga } from "../../lib/account-lifecycle";

const success = { error: null };
const failure = { error: { message: "unavailable" } };

describe("completePendingAuthBan", () => {
  it("persists failure and never reports completion when the Auth ban fails", async () => {
    const markFailure = vi.fn().mockResolvedValue(success);
    const markCompleted = vi.fn().mockResolvedValue(success);

    const result = await completePendingAuthBan({
      banAuthUser: vi.fn().mockResolvedValue(failure),
      markFailure,
      markCompleted,
    });

    expect(result).toEqual({ completed: false, error: "Auth ban failed. The account remains database-deprovisioned and is marked for an operator retry." });
    expect(markFailure).toHaveBeenCalledOnce();
    expect(markCompleted).not.toHaveBeenCalled();
  });

  it("does not report completion when durable completion recording fails", async () => {
    const markCompleted = vi.fn().mockResolvedValue(failure);

    const result = await completePendingAuthBan({
      banAuthUser: vi.fn().mockResolvedValue(success),
      markFailure: vi.fn().mockResolvedValue(success),
      markCompleted,
    });

    expect(result.completed).toBe(false);
    expect(markCompleted).toHaveBeenCalledOnce();
  });
});

describe("completeReprovisionSaga", () => {
  function dependencies(states: Array<"inactive" | "active" | "unknown">, overrides = {}) {
    return {
      resetPasswordAndUnban: vi.fn().mockResolvedValue(success),
      activateDatabase: vi.fn().mockResolvedValue(failure),
      readLifecycleState: vi.fn(async () => states.shift() ?? "unknown"),
      rebanAuthUser: vi.fn().mockResolvedValue(success),
      recordReconciliationNeeded: vi.fn().mockResolvedValue(success),
      ...overrides,
    };
  }

  it("re-bans only after an activation failure is confirmed database-inactive", async () => {
    const saga = dependencies(["inactive"]);
    const result = await completeReprovisionSaga(saga);

    expect(result).toEqual({ completed: false, reconciliationRequired: false, error: "Re-provisioning was not completed. The Auth identity was re-banned after the database account was confirmed inactive." });
    expect(saga.rebanAuthUser).toHaveBeenCalledOnce();
    expect(saga.recordReconciliationNeeded).not.toHaveBeenCalled();
  });

  it("requires operator review when confirmed-inactive compensation cannot re-ban Auth", async () => {
    const saga = dependencies(["inactive"], { rebanAuthUser: vi.fn().mockResolvedValue(failure) });
    const result = await completeReprovisionSaga(saga);

    expect(result).toMatchObject({ completed: false, reconciliationRequired: true, error: expect.stringContaining("could not be re-banned") });
    expect(saga.rebanAuthUser).toHaveBeenCalledOnce();
    expect(saga.recordReconciliationNeeded).toHaveBeenCalledOnce();
  });

  it("reports a failed audit without changing the failed-reban outcome", async () => {
    const saga = dependencies(["inactive"], {
      rebanAuthUser: vi.fn().mockResolvedValue(failure),
      recordReconciliationNeeded: vi.fn().mockResolvedValue(failure),
    });
    const result = await completeReprovisionSaga(saga);

    expect(result).toMatchObject({
      completed: false,
      reconciliationRequired: true,
      error: expect.stringContaining("could not be re-banned"),
    });
    expect(result).toMatchObject({ error: expect.stringContaining("reconciliation audit record could not be persisted") });
    expect(saga.recordReconciliationNeeded).toHaveBeenCalledOnce();
  });

  it("records reconciliation when activation errors but the database account is active", async () => {
    const saga = dependencies(["active"]);
    const result = await completeReprovisionSaga(saga);

    expect(result).toMatchObject({ completed: false, reconciliationRequired: true, error: expect.stringContaining("database account is active") });
    expect(saga.rebanAuthUser).not.toHaveBeenCalled();
    expect(saga.recordReconciliationNeeded).toHaveBeenCalledOnce();
  });

  it("reports a failed audit without changing the active-after-error outcome", async () => {
    const saga = dependencies(["active"], { recordReconciliationNeeded: vi.fn().mockResolvedValue(failure) });
    const result = await completeReprovisionSaga(saga);

    expect(result).toMatchObject({
      completed: false,
      reconciliationRequired: true,
      error: expect.stringContaining("database account is active"),
    });
    expect(result).toMatchObject({ error: expect.stringContaining("reconciliation audit record could not be persisted") });
    expect(saga.rebanAuthUser).not.toHaveBeenCalled();
    expect(saga.recordReconciliationNeeded).toHaveBeenCalledOnce();
  });

  it("does not re-ban when repeated lifecycle reads are unknown and records reconciliation", async () => {
    const saga = dependencies(["unknown", "unknown", "unknown"]);
    const result = await completeReprovisionSaga(saga);

    expect(result).toMatchObject({ completed: false, reconciliationRequired: true, error: expect.stringContaining("could not be reconciled") });
    expect(saga.readLifecycleState).toHaveBeenCalledTimes(3);
    expect(saga.rebanAuthUser).not.toHaveBeenCalled();
    expect(saga.recordReconciliationNeeded).toHaveBeenCalledOnce();
  });

  it("does not re-ban after successful database activation", async () => {
    const saga = dependencies([], { activateDatabase: vi.fn().mockResolvedValue(success) });
    const result = await completeReprovisionSaga(saga);

    expect(result).toEqual({ completed: true });
    expect(saga.rebanAuthUser).not.toHaveBeenCalled();
    expect(saga.readLifecycleState).not.toHaveBeenCalled();
  });
});
