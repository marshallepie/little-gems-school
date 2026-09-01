import { describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  redirect: vi.fn((path: string) => { throw new Error(`redirect:${path}`); }),
  createClient: vi.fn(),
}));
vi.mock("next/navigation", () => ({ redirect: mocks.redirect }));
vi.mock("@/lib/supabase/server", () => ({ createClient: mocks.createClient }));
vi.mock("@/lib/validations/roles", () => ({
  roleCodeSchema: { safeParse: (value: unknown) => ({ success: true, data: value }) },
}));

import { requireRole } from "../../lib/auth/require-role";

function clientWithIncompleteProfile() {
  return {
    auth: { getClaims: vi.fn().mockResolvedValue({ data: { claims: { sub: "11111111-1111-1111-1111-111111111111" } } }) },
    from: vi.fn(() => ({
      select: vi.fn(() => ({
        eq: vi.fn(() => ({
          maybeSingle: vi.fn().mockResolvedValue({ data: { profile_completed_at: null, is_active: true }, error: null }),
        })),
      })),
    })),
  };
}

describe("central profile completion guard", () => {
  it("redirects an incomplete authenticated user before a direct portal role check can authorize", async () => {
    mocks.createClient.mockResolvedValue(clientWithIncompleteProfile());

    await expect(requireRole()).rejects.toThrow("redirect:/profile");
    expect(mocks.redirect).toHaveBeenCalledWith("/profile");
  });
});
