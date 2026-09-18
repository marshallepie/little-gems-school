import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  requireProprietorSession: vi.fn(),
  requireAccountManagementSession: vi.fn(),
  createAdminClient: vi.fn(),
  revalidatePath: vi.fn(),
  completePendingAuthBan: vi.fn(),
  completeReprovisionSaga: vi.fn(),
}));
vi.mock("@/lib/auth/require-role", () => ({
  requireProprietorSession: mocks.requireProprietorSession,
  requireAccountManagementSession: mocks.requireAccountManagementSession,
}));
vi.mock("@/lib/supabase/admin", () => ({ createAdminClient: mocks.createAdminClient }));
vi.mock("@/lib/account-lifecycle", () => ({
  completePendingAuthBan: mocks.completePendingAuthBan,
  completeReprovisionSaga: mocks.completeReprovisionSaga,
}));
vi.mock("next/cache", () => ({ revalidatePath: mocks.revalidatePath }));

import { purgeDisposableTestAccount } from "../../app/admin/account-actions";

const userId = "11111111-1111-4111-8111-111111111111";
const proprietorId = "22222222-2222-4222-8222-222222222222";
const formData = () => {
  const form = new FormData();
  form.set("userId", userId);
  form.set("confirmation", "PURGE DISPOSABLE");
  return form;
};

function adminClient(readBack: { data: { user: unknown | null }; error: unknown }, deleteError: unknown = null) {
  const rpc = vi.fn().mockResolvedValue({ error: null });
  const deleteUser = vi.fn().mockResolvedValue({ error: deleteError });
  const getUserById = vi.fn().mockResolvedValue(readBack);
  return { client: { rpc, auth: { admin: { deleteUser, getUserById } } }, rpc, deleteUser, getUserById };
}

describe("purgeDisposableTestAccount Auth reconciliation", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.requireProprietorSession.mockResolvedValue({ userId: proprietorId });
  });

  it("accepts only the expected not-found read-back and then revalidates", async () => {
    const admin = adminClient({ data: { user: null }, error: { status: 404 } });
    mocks.createAdminClient.mockReturnValue(admin.client);

    await expect(purgeDisposableTestAccount(formData())).resolves.toBeUndefined();

    expect(admin.rpc).toHaveBeenCalledTimes(1);
    expect(admin.getUserById).toHaveBeenCalledWith(userId);
    expect(mocks.revalidatePath).toHaveBeenCalledWith("/admin/accounts");
  });

  it("records reconciliation and does not report success for an ambiguous null-user read-back", async () => {
    const admin = adminClient({ data: { user: null }, error: null });
    mocks.createAdminClient.mockReturnValue(admin.client);

    await expect(purgeDisposableTestAccount(formData())).rejects.toThrow("verification failed");

    expect(admin.rpc).toHaveBeenNthCalledWith(1, "begin_disposable_account_purge_from_server", { target_user_id: userId, actor_user_id: proprietorId });
    expect(admin.rpc).toHaveBeenNthCalledWith(2, "record_disposable_account_purge_auth_verification_failed_from_server", { target_user_id: userId, actor_user_id: proprietorId });
    expect(mocks.revalidatePath).not.toHaveBeenCalled();
  });

  it("records reconciliation and does not report success on a verification transport error", async () => {
    const admin = adminClient({ data: { user: null }, error: { status: 503, message: "upstream unavailable" } });
    mocks.createAdminClient.mockReturnValue(admin.client);

    await expect(purgeDisposableTestAccount(formData())).rejects.toThrow("verification failed");

    expect(admin.rpc).toHaveBeenNthCalledWith(1, "begin_disposable_account_purge_from_server", { target_user_id: userId, actor_user_id: proprietorId });
    expect(admin.rpc).toHaveBeenNthCalledWith(2, "record_disposable_account_purge_auth_verification_failed_from_server", { target_user_id: userId, actor_user_id: proprietorId });
    expect(mocks.revalidatePath).not.toHaveBeenCalled();
  });

  it("records reconciliation and does not report success when Auth still returns a user", async () => {
    const admin = adminClient({ data: { user: { id: userId } }, error: null });
    mocks.createAdminClient.mockReturnValue(admin.client);

    await expect(purgeDisposableTestAccount(formData())).rejects.toThrow("could not be verified");

    expect(admin.rpc).toHaveBeenNthCalledWith(2, "record_disposable_account_purge_auth_verification_failed_from_server", { target_user_id: userId, actor_user_id: proprietorId });
    expect(mocks.revalidatePath).not.toHaveBeenCalled();
  });
});
