import { z } from "zod";

const slug = z.string().trim().toLowerCase().regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/, "Use lowercase letters, numbers, and hyphens").max(120);
const text = (label: string, max: number) => z.string().trim().min(1, `${label} is required`).max(max, `${label} is too long`);
const optionalDateTime = z.union([z.string().datetime({ offset: true }), z.literal("")]);
const dateTimeWithOffset = z.string().datetime({ offset: true });

export const cmsPageSchema = z.object({
  id: z.string().uuid().optional(),
  slug,
  title: text("Title", 160),
  summary: z.string().trim().max(500, "Summary must be 500 characters or fewer"),
  body: z.string().trim().max(20_000, "Body must be 20,000 characters or fewer"),
  status: z.enum(["draft", "published"]),
});

export const cmsNewsSchema = z.object({
  id: z.string().uuid().optional(),
  slug,
  title: text("Title", 160),
  excerpt: z.string().trim().max(500, "Excerpt must be 500 characters or fewer"),
  body: z.string().trim().max(20_000, "Body must be 20,000 characters or fewer"),
  status: z.enum(["draft", "published"]),
  published_at: optionalDateTime,
});

export const cmsEventSchema = z.object({
  id: z.string().uuid().optional(),
  slug,
  title: text("Title", 160),
  summary: z.string().trim().max(500, "Summary must be 500 characters or fewer"),
  details: z.string().trim().max(20_000, "Details must be 20,000 characters or fewer"),
  starts_at: dateTimeWithOffset,
  ends_at: dateTimeWithOffset,
  status: z.enum(["draft", "published"]),
}).refine(({ starts_at, ends_at }) => ends_at > starts_at, { path: ["ends_at"], message: "End date and time must be after the start" });

export const cmsDeleteSchema = z.object({ id: z.string().uuid(), kind: z.enum(["page", "news", "event"]) });
