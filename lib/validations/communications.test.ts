import { describe, expect, it } from "vitest";
import { announcementSchema, eventSchema, parseAudiences, parseUtcDateTime } from "./communications";

const classId = "11111111-1111-4111-8111-111111111111";
// Existing deterministic class IDs are valid PostgreSQL UUIDs even with a version-0 nibble.
const legacyClassId = "40000000-0000-0000-0000-000000000001";
const event = { id: "", title: "Event", description: "", intent: "publish" as const, audiences: ["school"] };
describe("internal communications validation", () => {
  it("accepts only distinct supported school, role, or class audiences", () => {
    expect(parseAudiences(["school", "role:parent", `class:${classId}`])).toEqual([
      { target_kind: "school", role_code: null, class_group_id: null },
      { target_kind: "role", role_code: "parent", class_group_id: null },
      { target_kind: "class", role_code: null, class_group_id: classId },
    ]);
    expect(parseAudiences([`class:${legacyClassId}`])).toEqual([
      { target_kind: "class", role_code: null, class_group_id: legacyClassId },
    ]);
    expect(parseAudiences(["role:staff"])).toBeNull();
    expect(parseAudiences(["school", "school"])).toBeNull();
  });
  it("requires a plain-text announcement and at least one audience", () => {
    expect(announcementSchema.safeParse({ id: "", title: "Notice", body: "Plain text", intent: "draft", audiences: ["school"] }).success).toBe(true);
    expect(announcementSchema.safeParse({ id: "", title: "", body: "Plain text", intent: "draft", audiences: [] }).success).toBe(false);
  });
  it("treats datetime-local fields as UTC only after a real calendar round-trip", () => {
    expect(parseUtcDateTime("2028-02-29T09:00")).toBe("2028-02-29T09:00:00.000Z");
    expect(parseUtcDateTime("2026-02-29T09:00")).toBeNull();
    expect(parseUtcDateTime("2026-04-31T09:00")).toBeNull();
    expect(parseUtcDateTime("2026-01-01T24:00")).toBeNull();
    expect(parseUtcDateTime("2026-01-01T09:60")).toBeNull();
    expect(parseUtcDateTime("2026-01-01 09:00")).toBeNull();
  });
  it("rejects malformed and non-increasing UTC event boundaries", () => {
    expect(eventSchema.safeParse({ ...event, starts_at: "2026-09-10T09:00", ends_at: "2026-09-10T10:00" }).success).toBe(true);
    expect(eventSchema.safeParse({ ...event, starts_at: "2026-02-29T09:00", ends_at: "2026-03-01T10:00" }).success).toBe(false);
    expect(eventSchema.safeParse({ ...event, starts_at: "2026-09-10T10:00", ends_at: "2026-09-10T09:00" }).success).toBe(false);
    expect(eventSchema.safeParse({ ...event, starts_at: "2026-09-10T10:00", ends_at: "2026-09-10T10:00" }).success).toBe(false);
  });
});
