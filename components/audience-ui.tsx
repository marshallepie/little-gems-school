import type { ReactNode } from "react";

export type AudienceTarget = { target_kind: string; role_code: string | null; class_group_id: string | null };
export function AudienceLabels({ targets, classes }: { targets: AudienceTarget[]; classes: { id: string; name: string; level: string }[] }) {
  const classNames = new Map(classes.map((group) => [group.id, `${group.level}: ${group.name}`]));
  return <p className="text-sm text-slate-700">Audience: {targets.map((target) => target.target_kind === "school" ? "Whole school" : target.target_kind === "role" ? target.role_code : classNames.get(target.class_group_id ?? "") ?? "Current class").join(", ")}</p>;
}
export function AudienceOptions({ classes, selected = [] }: { classes: { id: string; name: string; level: string }[]; selected?: AudienceTarget[] }) {
  const selectedTokens = new Set(selected.map((target) => target.target_kind === "school" ? "school" : target.target_kind === "role" ? `role:${target.role_code}` : `class:${target.class_group_id}`));
  const option = (token: string, label: string) => <label key={token} className="flex min-h-11 items-center gap-2 rounded border p-3"><input name="audiences" type="checkbox" value={token} defaultChecked={selectedTokens.has(token)} /><span>{label}</span></label>;
  return <fieldset className="space-y-2"><legend className="font-semibold">Audience</legend><p className="text-sm text-slate-700">Choose one or more current audiences. Published items are only visible when database RLS matches a recipient.</p>{option("school", "Whole school")}<div className="grid gap-2 sm:grid-cols-2">{["teacher", "parent", "student", "admin"].map((role) => option(`role:${role}`, `${role[0].toUpperCase()}${role.slice(1)} role`))}</div>{classes.map((group) => option(`class:${group.id}`, `${group.level}: ${group.name}`))}</fieldset>;
}
export function Notice({ notice, error }: { notice?: string; error?: string }) { return <>{notice && <p role="status" className="rounded border border-green-300 bg-green-50 p-3">{notice.replaceAll("+", " ")}</p>}{error && <p role="alert" className="rounded border border-red-300 bg-red-50 p-3">{error}</p>}</>; }
export function FeedShell({ title, children }: { title: string; children: ReactNode }) { return <section className="space-y-4" aria-label={title}>{children}</section>; }
