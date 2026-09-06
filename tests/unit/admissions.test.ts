import { describe, expect, it } from "vitest";
import { applicationReviewSchema, applicationSchema, supportingDocumentError } from "../../lib/validations/admissions";

const valid = {
  child_first_name: "Ada", child_last_name: "Okafor", child_date_of_birth: "2021-05-12", requested_class: "Nursery 1",
  guardian_first_name: "Chinwe", guardian_last_name: "Okafor", guardian_relationship: "Mother", guardian_email: "chinwe@example.test",
  guardian_phone: "+2348000000000", alternate_phone: "", support_notes: "", consent: "on", website: "",
};

describe("public admissions validation", () => {
  it("accepts a bounded legitimate application", () => {
    expect(applicationSchema.safeParse(valid).success).toBe(true);
  });
  it("accepts no supporting documents while retaining the three-document limit", () => {
    expect(supportingDocumentError([])).toBeUndefined();
    const document = new File(["document"], "document.pdf", { type: "application/pdf" });
    expect(supportingDocumentError([document, document, document, document])).toBe("You can attach up to three supporting documents.");
  });
  it("rejects malformed applicant data, missing consent, and honeypot submissions", () => {
    expect(applicationSchema.safeParse({ ...valid, guardian_email: "not-an-email" }).success).toBe(false);
    expect(applicationSchema.safeParse({ ...valid, consent: "" }).success).toBe(false);
    expect(applicationSchema.safeParse({ ...valid, website: "bot-value" }).success).toBe(false);
  });
  it("limits staff review transitions and notes", () => {
    expect(applicationReviewSchema.safeParse({ application_id: "11111111-1111-4111-8111-111111111111", status: "accepted", staff_notes: "Reviewed" }).success).toBe(true);
    expect(applicationReviewSchema.safeParse({ application_id: "bad", status: "enrolled", staff_notes: "" }).success).toBe(false);
  });
});
