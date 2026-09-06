import Image from "next/image";
import Link from "next/link";
import { PublicNavigation } from "@/components/public-navigation";

export function PublicHeader() {
  return <header className="relative border-b border-violet-100 bg-white"><a className="sr-only focus:not-sr-only focus:absolute focus:z-30 focus:m-3 focus:rounded focus:bg-white focus:p-3" href="#main-content">Skip to main content</a><div className="mx-auto flex max-w-6xl items-center justify-between gap-2 px-4 py-3 sm:px-6"><Link className="flex min-w-0 items-center gap-2 font-bold no-underline sm:gap-3" href="/"><Image alt="Little Gems Private School crest" className="h-11 w-11 shrink-0 rounded-full object-contain" height={528} src="/images/little-gems-school-logo.jpg" width={528} /><span className="truncate">Little Gems <span className="hidden sm:inline">Private School</span></span></Link><PublicNavigation /></div></header>;
}

export function PublicFooter() { return <footer className="mt-12 border-t border-violet-100 bg-white"><div className="mx-auto flex max-w-6xl flex-col justify-between gap-3 px-4 py-6 text-sm sm:flex-row sm:px-6"><p>Little Gems Private School · “Winning From The Start”</p><div className="flex gap-4"><Link href="/admissions">Register now</Link><Link href="/login">School login</Link></div></div></footer>; }

export function PublicPage({ eyebrow, title, children }: { eyebrow: string; title: string; children: React.ReactNode }) { return <main id="main-content" className="mx-auto max-w-6xl px-4 py-10 sm:px-6"><nav aria-label="Breadcrumb" className="mb-6 text-sm"><ol className="flex flex-wrap items-center gap-2"><li><Link href="/">Home</Link></li><li aria-hidden="true">/</li><li aria-current="page" className="font-semibold text-slate-700">{title}</li></ol></nav><header className="max-w-3xl space-y-3"><p className="font-semibold uppercase tracking-wider text-violet-700">{eyebrow}</p><h1 className="text-4xl font-bold tracking-tight sm:text-5xl">{title}</h1></header>{children}</main>; }

export function EditorPrompt({ children }: { children: React.ReactNode }) { return <aside className="mt-8 rounded-xl border border-violet-200 bg-violet-50 p-5 text-slate-800"><h2 className="font-bold">Information being prepared</h2><p className="mt-2">{children}</p></aside>; }
