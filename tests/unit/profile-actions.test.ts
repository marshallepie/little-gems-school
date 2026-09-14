import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  requireActiveProfileSession: vi.fn(),
  createAdminClient: vi.fn(),
  redirect: vi.fn((path: string) => { throw new Error(`redirect:${path}`); }),
  revalidatePath: vi.fn(),
}));
vi.mock("../../lib/auth/require-role", () => ({ requireActiveProfileSession: mocks.requireActiveProfileSession }));
vi.mock("../../lib/supabase/admin", () => ({ createAdminClient: mocks.createAdminClient }));
vi.mock("next/navigation", () => ({ redirect: mocks.redirect }));
vi.mock("next/cache", () => ({ revalidatePath: mocks.revalidatePath }));
import { updateMyProfile } from "../../app/profile/actions";

const userId = "11111111-1111-1111-1111-111111111111";
function formData(values: Record<string, string>) { const data = new FormData(); Object.entries(values).forEach(([key, value]) => data.set(key, value)); return data; }
function session(update: ReturnType<typeof vi.fn>, avatarPath: string | null = null) {
  const maybeSingle = vi.fn().mockResolvedValue({ data: { avatar_path: avatarPath }, error: null });
  const eq = vi.fn(() => ({ maybeSingle }));
  return { supabase: { from: vi.fn(() => ({ select: vi.fn(() => ({ eq })), update })) }, userId };
}

describe("updateMyProfile", () => {
  beforeEach(() => vi.clearAllMocks());
  it("updates only validated self-contact fields and never accepts an avatar URL", async () => {
    const updateEq = vi.fn().mockResolvedValue({ error: null });
    const update = vi.fn(() => ({ eq: updateEq }));
    mocks.requireActiveProfileSession.mockResolvedValue(session(update));
    await expect(updateMyProfile(formData({ display_name: "  Ada Lovelace  ", phone: " +234 555 ", address: "  1 Gem Street ", avatar_url: "https://attacker.test/a.png", id: "222" }))).rejects.toThrow("redirect:/dashboard");
    expect(update).toHaveBeenCalledWith({ display_name: "Ada Lovelace", phone: "+234 555", address: "1 Gem Street", profile_completed_at: expect.any(String) });
    expect(updateEq).toHaveBeenCalledWith("id", userId);
    expect(mocks.revalidatePath).toHaveBeenCalledWith("/profile");
    expect(mocks.createAdminClient).not.toHaveBeenCalled();
  });
  it("uses the service client only for the narrowly granted avatar_path removal", async () => {
    const updateEq = vi.fn().mockResolvedValue({ error: null });
    const update = vi.fn(() => ({ eq: updateEq }));
    const adminUpdateEq = vi.fn().mockResolvedValue({ error: null });
    const adminUpdate = vi.fn(() => ({ eq: adminUpdateEq }));
    const remove = vi.fn().mockResolvedValue({ error: null });
    mocks.requireActiveProfileSession.mockResolvedValue(session(update, "avatars/11111111-1111-1111-1111-111111111111/22222222-2222-4222-8222-222222222222.png"));
    mocks.createAdminClient.mockReturnValue({ from: vi.fn(() => ({ update: adminUpdate })), storage: { from: vi.fn(() => ({ remove })) } });

    await expect(updateMyProfile(formData({ display_name: "Ada Lovelace", phone: "", address: "", remove_avatar: "on" }))).rejects.toThrow("redirect:/dashboard");

    expect(adminUpdate).toHaveBeenCalledWith({ avatar_path: null });
    expect(adminUpdateEq).toHaveBeenCalledWith("id", userId);
    expect(update).toHaveBeenCalledWith({ display_name: "Ada Lovelace", phone: null, address: null, profile_completed_at: expect.any(String) });
  });

  it("rejects invalid profile fields before checking session or writing", async () => {
    const update = vi.fn();
    await expect(updateMyProfile(formData({ display_name: "", phone: "", address: "" }))).rejects.toThrow("redirect:/profile?error=");
    expect(mocks.requireActiveProfileSession).not.toHaveBeenCalled();
    expect(update).not.toHaveBeenCalled();
  });
});
