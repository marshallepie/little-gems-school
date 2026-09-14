import { redirect } from "next/navigation";
import { requireRole } from "@/lib/auth/require-role";

export const dynamic = "force-dynamic";

export default async function DashboardPage() {
  const role = await requireRole();
  if (role === "admin") redirect("/admin/dashboard");
  if (role === "teacher") redirect("/teacher");
  if (role === "parent") redirect("/parent");
  if (role === "secretary") redirect("/admin/cms");
  redirect("/student");
}
