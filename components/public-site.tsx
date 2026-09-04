import Image from "next/image";
import Link from "next/link";

const links = [
  ["Home", "/"], ["About", "/about"], ["Academics", "/academics"], ["Admissions", "/admissions"], ["News", "/news"], ["Events", "/events"], ["Contact", "/contact"],
] as const;

export function PublicHeader() {
  return <header className="border-b border-violet-100 bg-white"><a className="sr-only focus:not-sr-only focus:absolute focus:z-10 focus:m-3 focus:rounded focus:bg-white focus:p-3" href="#main-content">Skip to main content</a><div className="mx-auto flex max-w-6xl flex-wrap items-center justify-between gap-4 px-4 py-3 sm:px-6"><Link className="flex items-center gap-3 font-bold no-underline" href="/"><Image alt="Little Gems Private School crest" className="h-12 w-12 rounded-full object-contain" height={528} src="/images/little-gems-school-logo.jpg" width={528} /><span>Little Gems <span className="hidden sm:inline">Private School</span></span></Link><nav aria-label="Public site"><ul className="flex flex-wrap items-center justify-center gap-x-4 gap-y-2 text-sm font-semibold">{links.map(([label, href]) => <li key={href}><Link className="no-underline hover:underline" href={href as never}>{label}</Link></li>)}<li><Link className="primary-cta inline-flex min-h-10 items-center rounded px-3 no-underline" href="/login">School login</Link></li></ul></nav></div></header>;
}

export function PublicFooter() { return <footer className="mt-12 border-t border-violet-100 bg-white"><div className="mx-auto flex max-w-6xl flex-col justify-between gap-3 px-4 py-6 text-sm sm:flex-row sm:px-6"><p>Little Gems Private School · “Winning From The Start”</p><Link href="/login">School login</Link></div></footer>; }

export function PublicPage({ eyebrow, title, children }: { eyebrow: string; title: string; children: React.ReactNode }) { return <main id="main-content" className="mx-auto max-w-6xl px-4 py-10 sm:px-6"><header className="max-w-3xl space-y-3"><p className="font-semibold uppercase tracking-wider text-violet-700">{eyebrow}</p><h1 className="text-4xl font-bold tracking-tight sm:text-5xl">{title}</h1></header>{children}</main>; }

export function EditorPrompt({ children }: { children: React.ReactNode }) { return <aside className="mt-8 rounded-xl border border-violet-200 bg-violet-50 p-5 text-slate-800"><h2 className="font-bold">Information being prepared</h2><p className="mt-2">{children}</p></aside>; }
