import { redirect } from "next/navigation";
import { requireRole } from "@/lib/auth/require-role";

export const dynamic = "force-dynamic";

export default async function DashboardPage() {
  // requireRole centrally enforces the first-login completion gate before routing.
  const role = await requireRole();
  if (role === "admin") redirect("/admin/dashboard");
  if (role === "teacher") redirect("/teacher");
  if (role === "parent") redirect("/parent");
  redirect("/student");
}
