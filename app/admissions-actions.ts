"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createAdminClient } from "@/lib/supabase/admin";
import { requireAdminPermission } from "@/lib/auth/require-role";
import { applicationReviewSchema, applicationSchema, supportingDocumentError } from "@/lib/validations/admissions";
import { formValues } from "@/lib/validations/school";

function applicationError(message: string): never {
  redirect(`/admissions?error=${encodeURIComponent(message)}` as never);
}

export async function submitApplication(formData: FormData) {
  const parsed = applicationSchema.safeParse(formValues(formData));
  if (!parsed.success) applicationError(parsed.error.issues[0]?.message ?? "Please check the application form.");
  // A filled honeypot is silently rejected without recording any applicant data.
  if (parsed.data.website) applicationError("Unable to submit this application.");

  const files = formData.getAll("supporting_documents").filter((entry): entry is File => entry instanceof File && entry.size > 0);
  const documentError = supportingDocumentError(files);
  if (documentError) applicationError(documentError);

  const admin = createAdminClient();
  const { data: application, error: applicationInsertError } = await admin.from("admission_applications").insert({
    child_first_name: parsed.data.child_first_name,
    child_last_name: parsed.data.child_last_name,
    child_date_of_birth: parsed.data.child_date_of_birth,
    requested_class: parsed.data.requested_class,
    guardian_first_name: parsed.data.guardian_first_name,
    guardian_last_name: parsed.data.guardian_last_name,
    guardian_relationship: parsed.data.guardian_relationship,
    guardian_email: parsed.data.guardian_email,
    guardian_phone: parsed.data.guardian_phone,
    alternate_phone: parsed.data.alternate_phone || null,
    support_notes: parsed.data.support_notes || null,
  }).select("id, application_reference").single();
  if (applicationInsertError || !application) applicationError("We could not save your application. Please try again or contact the school.");

  try {
    for (const file of files) {
      const documentId = crypto.randomUUID();
      const storagePath = `admissions/${application.id}/${documentId}`;
      const { error: uploadError } = await admin.storage.from("school-documents").upload(storagePath, file, { contentType: file.type, upsert: false });
      if (uploadError) throw uploadError;
      const { error: documentError } = await admin.from("admission_application_documents").insert({
        id: documentId,
        application_id: application.id,
        storage_path: storagePath,
        original_file_name: file.name.slice(0, 255),
        mime_type: file.type,
        byte_size: file.size,
      });
      if (documentError) throw documentError;
    }
  } catch {
    // The incomplete private record is intentionally retained for staff follow-up;
    // no reference is presented to an applicant until all documents are recorded.
    applicationError("We could not safely save every supporting document. Please contact the school before trying again.");
  }
  redirect(`/admissions?reference=${encodeURIComponent(application.application_reference)}` as never);
}

export async function reviewApplication(formData: FormData) {
  const parsed = applicationReviewSchema.safeParse(formValues(formData));
  if (!parsed.success) redirect("/admin/admissions?error=Invalid+application+review" as never);
  await requireAdminPermission("people.manage");
  const admin = createAdminClient();
  const { error } = await admin.from("admission_applications").update({ status: parsed.data.status, staff_notes: parsed.data.staff_notes || null, reviewed_at: new Date().toISOString() }).eq("id", parsed.data.application_id);
  if (error) redirect(`/admin/admissions?error=${encodeURIComponent(error.message)}` as never);
  revalidatePath("/admin/admissions");
  redirect("/admin/admissions?notice=Application+review+saved" as never);
}
