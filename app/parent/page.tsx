import { redirect } from "next/navigation";
import { PortalPlaceholder } from "@/components/portal-placeholder";
import { requireRole } from "@/lib/auth/require-role";
export const dynamic = "force-dynamic";
export default async function ParentPage() { if (await requireRole() !== "parent") redirect("/dashboard"); return <PortalPlaceholder role="Parent / guardian" />; }
