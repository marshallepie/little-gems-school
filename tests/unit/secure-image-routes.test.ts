import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  createAdminClient: vi.fn(),
  createServerClient: vi.fn(),
  createPublicClient: vi.fn(),
}));
vi.mock("@/lib/supabase/admin", () => ({ createAdminClient: mocks.createAdminClient }));
vi.mock("@/lib/supabase/server", () => ({ createClient: mocks.createServerClient }));
vi.mock("@supabase/supabase-js", () => ({ createClient: mocks.createPublicClient }));

const validId = "11111111-1111-4111-8111-111111111111";
const otherUserId = "22222222-2222-4222-8222-222222222222";
const noStore = "private, no-store";

function signer(url = "https://storage.example.test/signed") {
  const createSignedUrl = vi.fn().mockResolvedValue({ data: { signedUrl: url }, error: null });
  return { client: { storage: { from: vi.fn(() => ({ createSignedUrl })) } }, createSignedUrl };
}
type PublicMediaRecord = { id: string; status: "draft" | "published" | "archived"; published_at: string; image_path: string | null };
function publicQuery(records: PublicMediaRecord[]) {
  const filters: Partial<Record<"id" | "status" | "published_at", string>> = {};
  const maybeSingle = vi.fn().mockImplementation(async () => {
    const data = records.find((record) => record.id === filters.id && record.status === filters.status && record.published_at <= (filters.published_at ?? ""));
    return { data: data ? { image_path: data.image_path } : null };
  });
  const lte = vi.fn((field: "published_at", value: string) => { filters[field] = value; return { maybeSingle }; });
  const eqStatus = vi.fn((field: "status", value: "published") => { filters[field] = value; return { lte }; });
  const eqId = vi.fn((field: "id", value: string) => { filters[field] = value; return { eq: eqStatus }; });
  const select = vi.fn(() => ({ eq: eqId }));
  return { client: { from: vi.fn(() => ({ select })) }, eqId, eqStatus, lte };
}
function avatarClient(userId: string | undefined, profile: { avatar_path: string | null; is_active: boolean } | null) {
  const maybeSingle = vi.fn().mockResolvedValue({ data: profile });
  const eq = vi.fn(() => ({ maybeSingle }));
  return { auth: { getClaims: vi.fn().mockResolvedValue({ data: { claims: userId ? { sub: userId } : {} } }) }, from: vi.fn(() => ({ select: vi.fn(() => ({ eq })) })), eq };
}

describe("public media route", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    process.env.NEXT_PUBLIC_SUPABASE_URL = "https://project.supabase.co";
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY = "anon-key";
  });

  async function request(records: PublicMediaRecord[] = [], kind = "page", id = validId) {
    const query = publicQuery(records);
    const signed = signer();
    mocks.createPublicClient.mockReturnValue(query.client);
    mocks.createAdminClient.mockReturnValue(signed.client);
    const { GET } = await import("../../app/api/public-media/[kind]/[id]/route");
    return { response: await GET(new Request("https://app.test"), { params: Promise.resolve({ kind, id }) }), query, signed };
  }

  const oldPublication = "2020-01-01T00:00:00.000Z";
  const publishedImage = "content/page/11111111-1111-4111-8111-111111111111/33333333-3333-4333-8333-333333333333.png";
  it.each([
    ["draft", [{ id: validId, status: "draft", published_at: oldPublication, image_path: publishedImage }]],
    ["archived", [{ id: validId, status: "archived", published_at: oldPublication, image_path: publishedImage }]],
    ["future published", [{ id: validId, status: "published", published_at: "2999-01-01T00:00:00.000Z", image_path: publishedImage }]],
    ["nonexistent", []],
    ["published without an image", [{ id: validId, status: "published", published_at: oldPublication, image_path: null }]],
  ] as const)("returns uncached 404 and does not sign %s media", async (_scenario, records) => {
    const { response, query, signed } = await request([...records]);
    expect(query.eqStatus).toHaveBeenCalledWith("status", "published");
    expect(query.lte).toHaveBeenCalledWith("published_at", expect.any(String));
    expect(response.status).toBe(404);
    expect(response.headers.get("Cache-Control")).toBe(noStore);
    expect(signed.createSignedUrl).not.toHaveBeenCalled();
  });

  it.each(["other", "toString", "constructor"])("rejects invalid or inherited kind %s before querying or signing", async (kind) => {
    const { response, query, signed } = await request([{ id: validId, status: "published", published_at: oldPublication, image_path: publishedImage }], kind);
    expect(response.status).toBe(404);
    expect(response.headers.get("Cache-Control")).toBe(noStore);
    expect(query.client.from).not.toHaveBeenCalled();
    expect(signed.createSignedUrl).not.toHaveBeenCalled();
  });

  it("rejects UUID-like but malformed IDs before querying or signing", async () => {
    const { response, query, signed } = await request([{ id: validId, status: "published", published_at: oldPublication, image_path: publishedImage }], "page", "11111111-1111-1111-1111-111111111111");
    expect(response.status).toBe(404);
    expect(response.headers.get("Cache-Control")).toBe(noStore);
    expect(query.client.from).not.toHaveBeenCalled();
    expect(signed.createSignedUrl).not.toHaveBeenCalled();
  });

  it("queries only published, already-public media and returns an uncached signed redirect", async () => {
    const { response, query, signed } = await request([{ id: validId, status: "published", published_at: oldPublication, image_path: publishedImage }]);
    expect(query.eqId).toHaveBeenCalledWith("id", validId);
    expect(query.eqStatus).toHaveBeenCalledWith("status", "published");
    expect(query.lte).toHaveBeenCalledWith("published_at", expect.any(String));
    expect(signed.createSignedUrl).toHaveBeenCalledTimes(1);
    expect(response.status).toBe(302);
    expect(response.headers.get("Location")).toBe("https://storage.example.test/signed");
    expect(response.headers.get("Cache-Control")).toBe(noStore);
  });
});

describe("profile avatar route", () => {
  beforeEach(() => vi.clearAllMocks());
  async function request(userId: string | undefined, profile: { avatar_path: string | null; is_active: boolean } | null) {
    const server = avatarClient(userId, profile);
    const signed = signer();
    mocks.createServerClient.mockResolvedValue(server);
    mocks.createAdminClient.mockReturnValue(signed.client);
    const { GET } = await import("../../app/api/profile/avatar/route");
    return { response: await GET(), server, signed };
  }

  it("denies anonymous callers without signing", async () => {
    const { response, signed } = await request(undefined, null);
    expect(response.status).toBe(401);
    expect(response.headers.get("Cache-Control")).toBe(noStore);
    expect(signed.createSignedUrl).not.toHaveBeenCalled();
  });

  it.each([{ avatar_path: "avatars/a.png", is_active: false }, null, { avatar_path: null, is_active: true }])("denies inactive, missing-profile, or no-avatar callers without signing", async (profile) => {
    const { response, signed } = await request(validId, profile);
    expect(response.status).toBe(404);
    expect(response.headers.get("Cache-Control")).toBe(noStore);
    expect(signed.createSignedUrl).not.toHaveBeenCalled();
  });

  it("uses only the authenticated owner ID, preventing cross-user avatar access", async () => {
    const { response, server, signed } = await request(otherUserId, null);
    expect(server.eq).toHaveBeenCalledWith("id", otherUserId);
    expect(response.status).toBe(404);
    expect(signed.createSignedUrl).not.toHaveBeenCalled();
  });

  it("returns an uncached redirect only for an active owner avatar", async () => {
    const { response, signed } = await request(validId, { avatar_path: "avatars/11111111-1111-4111-8111-111111111111/33333333-3333-4333-8333-333333333333.png", is_active: true });
    expect(signed.createSignedUrl).toHaveBeenCalledTimes(1);
    expect(response.status).toBe(302);
    expect(response.headers.get("Location")).toBe("https://storage.example.test/signed");
    expect(response.headers.get("Cache-Control")).toBe(noStore);
  });
});
