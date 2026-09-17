import { z } from "zod";
import { uuid } from "./school";

const audienceToken = z.string().trim().min(1);
// Class selector values are canonical UUID strings. Unlike Zod's UUID helper,
// this deliberately does not restrict the UUID version nibble; PostgreSQL casts
// and authorizes the value again in the command RPC.
const classAudienceUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const plainText = (label: string, max: number) => z.string().trim().min(1, `${label} is required`).max(max, `${label} must be ${max} characters or fewer`);
const localDateTime = z.string().regex(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/, "Choose a valid UTC date and time");

/**
 * `datetime-local` has no zone. This product deliberately treats its displayed
 * wall-clock fields as UTC, and verifies the Date round-trip so JS cannot
 * normalize impossible calendar values (for example 2026-02-29) silently.
 */
export function parseUtcDateTime(value: string): string | null {
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(value)) return null;
  const date = new Date(`${value}:00.000Z`);
  if (Number.isNaN(date.getTime()) || date.toISOString().slice(0, 16) !== value) return null;
  return date.toISOString();
}

export const announcementSchema = z.object({
  id: z.union([uuid, z.literal("")]),
  title: plainText("Title", 200),
  body: plainText("Message", 10_000),
  intent: z.enum(["draft", "publish", "archive"]),
  audiences: z.array(audienceToken).min(1, "Choose at least one audience"),
});

export const eventSchema = z.object({
  id: z.union([uuid, z.literal("")]),
  title: plainText("Title", 200),
  description: z.string().trim().max(10_000, "Description must be 10,000 characters or fewer"),
  starts_at: localDateTime,
  ends_at: localDateTime,
  intent: z.enum(["draft", "publish", "cancel"]),
  audiences: z.array(audienceToken).min(1, "Choose at least one audience"),
}).superRefine(({ starts_at, ends_at }, ctx) => {
  const startsAt = parseUtcDateTime(starts_at);
  const endsAt = parseUtcDateTime(ends_at);
  if (!startsAt) ctx.addIssue({ code: "custom", path: ["starts_at"], message: "Choose a real UTC date and time" });
  if (!endsAt) ctx.addIssue({ code: "custom", path: ["ends_at"], message: "Choose a real UTC date and time" });
  if (startsAt && endsAt && Date.parse(endsAt) <= Date.parse(startsAt)) {
    ctx.addIssue({ code: "custom", path: ["ends_at"], message: "End must be after start" });
  }
});

export type Audience = { target_kind: "school"; role_code: null; class_group_id: null } | { target_kind: "role"; role_code: "teacher" | "parent" | "student" | "admin"; class_group_id: null } | { target_kind: "class"; role_code: null; class_group_id: string };

export function parseAudiences(values: string[]): Audience[] | null {
  const parsed: Audience[] = [];
  for (const value of values) {
    if (value === "school") parsed.push({ target_kind: "school", role_code: null, class_group_id: null });
    else if (/^role:(admin|teacher|parent|student)$/.test(value)) parsed.push({ target_kind: "role", role_code: value.slice(5) as "admin" | "teacher" | "parent" | "student", class_group_id: null });
    else if (value.startsWith("class:") && classAudienceUuid.test(value.slice(6))) parsed.push({ target_kind: "class", role_code: null, class_group_id: value.slice(6) });
    else return null;
  }
  const deduped = new Map(parsed.map((audience) => [`${audience.target_kind}:${audience.role_code ?? ""}:${audience.class_group_id ?? ""}`, audience]));
  return deduped.size === parsed.length ? [...deduped.values()] : null;
}
