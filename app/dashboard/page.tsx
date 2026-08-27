import { redirect } from "next/navigation";
import { requireRole } from "@/lib/auth/require-role";

export const dynamic = "force-dynamic";
export default async function DashboardPage() { const role = await requireRole(); redirect(`/${role}`); }
