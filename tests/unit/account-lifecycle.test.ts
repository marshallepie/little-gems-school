import { describe, expect, it, vi } from "vitest";
import { completePendingAuthBan } from "../../lib/account-lifecycle";

describe("completePendingAuthBan", () => {
  it("persists failure and never reports completion when the Auth ban fails", async () => {
    const markFailure = vi.fn().mockResolvedValue({ error: null });
    const markCompleted = vi.fn().mockResolvedValue({ error: null });

    const result = await completePendingAuthBan({
      banAuthUser: vi.fn().mockResolvedValue({ error: { message: "Auth unavailable" } }),
      markFailure,
      markCompleted,
    });

    expect(result).toEqual({ completed: false, error: "Auth ban failed. The account remains database-deprovisioned and is marked for an operator retry." });
    expect(markFailure).toHaveBeenCalledOnce();
    expect(markCompleted).not.toHaveBeenCalled();
  });

  it("does not report completion when durable completion recording fails", async () => {
    const markCompleted = vi.fn().mockResolvedValue({ error: { message: "database unavailable" } });

    const result = await completePendingAuthBan({
      banAuthUser: vi.fn().mockResolvedValue({ error: null }),
      markFailure: vi.fn().mockResolvedValue({ error: null }),
      markCompleted,
    });

    expect(result.completed).toBe(false);
    expect(markCompleted).toHaveBeenCalledOnce();
  });
});
