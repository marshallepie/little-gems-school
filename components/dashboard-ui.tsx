import type { ReactNode } from "react";

export function PortalHeader({ eyebrow, title, children }: { eyebrow: string; title: string; children: ReactNode }) {
  return <header className="space-y-2"><p className="font-semibold text-[color:var(--gem)]">Little Gems School · {eyebrow}</p><h1 className="text-3xl font-bold tracking-tight">{title}</h1><div className="max-w-3xl text-slate-700">{children}</div></header>;
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
