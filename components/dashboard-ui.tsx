import Link from "next/link";
import type { Route } from "next";
import type { ReactNode } from "react";
import { PortalAccountControls } from "@/components/portal-account-controls";

export type PortalRole = "admin" | "teacher" | "parent" | "student" | "profile";

type PortalConfig = { role: PortalRole; label: string; homeHref: Route; links: { href: Route; label: string }[] };

function portalConfig(role: PortalRole): PortalConfig {
  switch (role) {
    case "admin":
      return { role, label: "Administrator", homeHref: "/admin/dashboard", links: [{ href: "/admin/dashboard", label: "Dashboard" }, { href: "/admin", label: "School records" }, { href: "/admin/operations/attendance", label: "Operations" }] };
    case "teacher":
      return { role, label: "Teacher", homeHref: "/teacher", links: [{ href: "/teacher", label: "Dashboard" }, { href: "/teacher/assignments", label: "Assignments" }, { href: "/teacher/attendance", label: "Attendance" }] };
    case "parent":
      return { role, label: "Parent", homeHref: "/parent", links: [{ href: "/parent", label: "Home" }, { href: "/profile", label: "Profile" }] };
    case "student":
      return { role, label: "Student", homeHref: "/student", links: [{ href: "/student", label: "Home" }, { href: "/student/assignments", label: "Assignments" }, { href: "/student/attendance", label: "Attendance" }] };
    case "profile":
      return { role, label: "Account", homeHref: "/dashboard", links: [{ href: "/dashboard", label: "Dashboard" }, { href: "/profile", label: "Profile" }] };
  }
}

function PortalNavigation({ config }: { config: PortalConfig }) {
  return <>
    <nav className={`portal-navigation portal-navigation-${config.role}`} aria-label={`${config.label} portal navigation`}>
      <div className="portal-navigation-links">
        {config.links.map((link) => <Link className="portal-navigation-link" href={link.href} key={link.href}>{link.label}</Link>)}
        <a className="portal-navigation-link" href="#portal-help">Need help?</a>
      </div>
      <Link className="portal-back-link" href={config.homeHref}>Back to {config.role === "parent" || config.role === "student" ? "home" : "dashboard"}</Link>
    </nav>
    <aside className="portal-help" id="portal-help" aria-label="Help using the portal">
      <p><strong>Need help?</strong> Use <Link href="/forgot-password">Forgot password</Link> if you cannot sign in. For help with school records or portal information, contact the school through its usual approved channel.</p>
    </aside>
  </>;
}

export function PortalHeader({ role, eyebrow, title, children }: { role: PortalRole; eyebrow: string; title: string; children: ReactNode }) {
  const config = portalConfig(role);
  return <header className="space-y-3"><div className="flex flex-wrap items-start justify-between gap-3"><div className="space-y-2"><p className="font-semibold text-[color:var(--gem)]">Little Gems School · {eyebrow}</p><h1 className="text-3xl font-bold tracking-tight">{title}</h1></div><PortalAccountControls /></div><div className="max-w-3xl text-slate-700">{children}</div><PortalNavigation config={config} /></header>;
}

export function DashboardCard({ title, children }: { title: string; children: ReactNode }) {
  return <section className="rounded-xl bg-white p-5 shadow-sm ring-1 ring-slate-200"><h2 className="text-lg font-bold">{title}</h2><div className="mt-3 space-y-3">{children}</div></section>;
}

export function EmptyDashboardState({ title, children }: { title: string; children: ReactNode }) {
  return <section className="rounded-xl border border-dashed border-slate-300 bg-white p-5" aria-labelledby="empty-state-title"><h2 id="empty-state-title" className="text-lg font-bold">{title}</h2><p className="mt-2 text-slate-700">{children}</p></section>;
}

export function UnavailableDashboardState() {
  return <section className="rounded-xl border border-dashed border-slate-300 bg-white p-5" aria-labelledby="unavailable-state-title"><h2 id="unavailable-state-title" className="text-lg font-bold">Information temporarily unavailable</h2><p className="mt-2 text-slate-700">Please try again later or contact the school if this continues.</p></section>;
}

export function FutureFeatureNote({ children }: { children: ReactNode }) {
  return <p className="rounded-lg bg-violet-50 p-3 text-sm text-slate-700"><span className="font-semibold text-[color:var(--gem)]">Coming later:</span> {children}</p>;
}
