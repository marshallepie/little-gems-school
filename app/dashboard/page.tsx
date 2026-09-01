import { redirect } from "next/navigation";
import { requireRole } from "@/lib/auth/require-role";

export const dynamic = "force-dynamic";
export default async function DashboardPage() {
  // requireRole centrally enforces the first-login completion gate before routing.
  redirect(`/${await requireRole()}`);
}
