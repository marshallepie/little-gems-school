import { describe, expect, it } from "vitest";
import { cmsDeleteSchema, cmsEventSchema, cmsNewsSchema, cmsPageSchema } from "../../lib/validations/cms";

describe("CMS draft workflow form contracts", () => {
  it("accepts a same-slug replacement target identifier without trusting publication fields", () => {
    expect(cmsDeleteSchema.safeParse({ id: "11111111-1111-4111-8111-111111111111", kind: "page" }).success).toBe(true);
    expect(cmsDeleteSchema.safeParse({ id: "not-a-uuid", kind: "page" }).success).toBe(false);
    expect(cmsPageSchema.safeParse({ slug: "existing-url", title: "Draft", summary: "", body: "", status: "draft" }).success).toBe(true);
  });

  it("keeps event and news drafts locally valid while publication remains server-controlled", () => {
    expect(cmsNewsSchema.safeParse({ slug: "news-url", title: "Draft", excerpt: "", body: "", status: "draft", published_at: "" }).success).toBe(true);
    expect(cmsEventSchema.safeParse({ slug: "event-url", title: "Draft", summary: "", details: "", starts_at: "2026-09-10T10:00:00.000Z", ends_at: "2026-09-10T11:00:00.000Z", status: "draft" }).success).toBe(true);
  });
});
