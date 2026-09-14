import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  createClient: vi.fn(),
  redirect: vi.fn((path: string) => { throw new Error(`redirect:${path}`); }),
  revalidatePath: vi.fn(),
}));

vi.mock("@/lib/supabase/server", () => ({ createClient: mocks.createClient }));
vi.mock("next/navigation", () => ({ redirect: mocks.redirect }));
vi.mock("next/cache", () => ({ revalidatePath: mocks.revalidatePath }));
vi.mock("@/lib/validations/roles", () => ({
  roleCodeSchema: { safeParse: (value: unknown) => ({ success: true, data: value }) },
}));

import { updateMyProfile } from "../../app/profile/actions";

const userId = "11111111-1111-1111-1111-111111111111";

function formData(values: Record<string, string>) {
  const data = new FormData();
  Object.entries(values).forEach(([key, value]) => data.set(key, value));
  return data;
}

function authenticatedClient(isActive: boolean, update: ReturnType<typeof vi.fn>) {
  const maybeSingle = vi.fn().mockResolvedValue({ data: { is_active: isActive }, error: null });
  const select = vi.fn(() => ({ eq: vi.fn(() => ({ maybeSingle })) }));
  return {
    auth: { getClaims: vi.fn().mockResolvedValue({ data: { claims: { sub: userId } } }) },
    from: vi.fn(() => ({ select, update })),
  };
}

describe("updateMyProfile", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("updates only validated self-contact fields and targets the authenticated user", async () => {
    const eq = vi.fn().mockResolvedValue({ error: null });
    const update = vi.fn((payload: Record<string, unknown>) => { void payload; return { eq }; });
    mocks.createClient.mockResolvedValue(authenticatedClient(true, update));

    await expect(updateMyProfile(formData({
      display_name: "  Ada Lovelace  ", phone: " +234 555 ", address: "  1 Gem Street ", avatar_url: "https://example.test/avatar.png",
      id: "22222222-2222-2222-2222-222222222222", default_role_code: "admin", is_active: "false",
    }))).rejects.toThrow("redirect:/dashboard");

    expect(update).toHaveBeenCalledWith(expect.objectContaining({
      display_name: "Ada Lovelace", phone: "+234 555", address: "1 Gem Street", avatar_url: "https://example.test/avatar.png",
      profile_completed_at: expect.any(String),
    }));
    expect(Object.keys(update.mock.calls[0][0]).sort()).toEqual(["address", "avatar_url", "display_name", "phone", "profile_completed_at"]);
    expect(eq).toHaveBeenCalledWith("id", userId);
    expect(mocks.revalidatePath).toHaveBeenCalledWith("/profile");
  });

  it("rejects an inactive authenticated account before any profile update", async () => {
    const update = vi.fn();
    mocks.createClient.mockResolvedValue(authenticatedClient(false, update));

    await expect(updateMyProfile(formData({ display_name: "Ada", phone: "", address: "", avatar_url: "" }))).rejects.toThrow("redirect:/login");

    expect(update).not.toHaveBeenCalled();
    expect(mocks.revalidatePath).not.toHaveBeenCalled();
  });

  it("rejects an authenticated identity with no profile before any profile update", async () => {
    const update = vi.fn();
    const maybeSingle = vi.fn().mockResolvedValue({ data: null, error: null });
    mocks.createClient.mockResolvedValue({
      auth: { getClaims: vi.fn().mockResolvedValue({ data: { claims: { sub: userId } } }) },
      from: vi.fn(() => ({ select: vi.fn(() => ({ eq: vi.fn(() => ({ maybeSingle })) })), update })),
    });

    await expect(updateMyProfile(formData({ display_name: "Ada", phone: "", address: "", avatar_url: "" }))).rejects.toThrow("redirect:/login");

    expect(update).not.toHaveBeenCalled();
  });

  it("does not write a profile when there is no authenticated user", async () => {
    const update = vi.fn();
    mocks.createClient.mockResolvedValue({
      auth: { getClaims: vi.fn().mockResolvedValue({ data: { claims: {} } }) },
      from: vi.fn(() => ({ update })),
    });

    await expect(updateMyProfile(formData({ display_name: "Ada", phone: "", address: "", avatar_url: "" }))).rejects.toThrow("redirect:/login");
    expect(update).not.toHaveBeenCalled();
  });

  it("rejects invalid avatar URLs before attempting an update", async () => {
    const update = vi.fn();
    await expect(updateMyProfile(formData({ display_name: "Ada", phone: "", address: "", avatar_url: "http://example.test/avatar.png" }))).rejects.toThrow("redirect:/profile?error=");
    expect(mocks.createClient).not.toHaveBeenCalled();
    expect(update).not.toHaveBeenCalled();
  });
});
