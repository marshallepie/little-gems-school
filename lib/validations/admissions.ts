import { z } from "zod";

const name = z.string().trim().min(1, "This field is required").max(100, "Must be 100 characters or fewer");
const phone = z.string().trim().min(7, "Enter a valid phone number").max(40, "Phone number is too long");

export const applicationSchema = z.object({
  child_first_name: name,
  child_last_name: name,
  child_date_of_birth: z.string().date("Choose a valid date"),
  requested_class: z.string().trim().min(1, "Choose a requested class").max(100, "Requested class is too long"),
  guardian_first_name: name,
  guardian_last_name: name,
  guardian_relationship: z.string().trim().min(1, "State your relationship to the child").max(80, "Relationship is too long"),
  guardian_email: z.string().trim().email("Enter a valid email address").max(254),
  guardian_phone: phone,
  alternate_phone: z.union([z.literal(""), phone]),
  support_notes: z.string().trim().max(2_000, "Support notes must be 2,000 characters or fewer"),
  consent: z.literal("on", "You must confirm you may submit this application"),
  website: z.literal(""),
});

export const applicationStatusSchema = z.enum(["pending_review", "contacted", "accepted", "declined", "withdrawn"]);
export const applicationReviewSchema = z.object({
  application_id: z.string().uuid(),
  status: applicationStatusSchema,
  staff_notes: z.string().trim().max(2_000, "Staff notes must be 2,000 characters or fewer"),
});

export const allowedApplicationDocumentTypes = ["application/pdf", "image/jpeg", "image/png"] as const;
export const MAX_APPLICATION_DOCUMENT_BYTES = 10 * 1024 * 1024;

export function supportingDocumentError(files: File[]): string | undefined {
  if (files.length > 3) return "You can attach up to three supporting documents.";
  for (const file of files) {
    if (file.size > MAX_APPLICATION_DOCUMENT_BYTES) return "Each supporting document must be 10 MB or smaller.";
    if (!allowedApplicationDocumentTypes.includes(file.type as (typeof allowedApplicationDocumentTypes)[number])) return "Supporting documents must be PDFs, JPEGs, or PNGs.";
  }
}
