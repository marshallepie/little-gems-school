"use client";

import Link from "next/link";
import { useState } from "react";

const links = [
  ["Home", "/"], ["About", "/about"], ["Academics", "/academics"], ["Admissions", "/admissions"], ["News", "/news"], ["Events", "/events"], ["Contact", "/contact"],
] as const;

export function PublicNavigation() {
  const [open, setOpen] = useState(false);
  return <div className="flex items-center gap-2">
    <button aria-controls="public-navigation" aria-expanded={open} className="inline-flex min-h-11 items-center rounded border border-violet-300 px-3 font-semibold text-violet-950 md:hidden" onClick={() => setOpen((value) => !value)} type="button">
      <span aria-hidden="true" className="mr-2 text-lg leading-none">☰</span>{open ? "Close menu" : "Menu"}
    </button>
    <nav aria-label="Public site" className={`${open ? "absolute inset-x-0 top-full z-20 border-b border-violet-100 bg-white p-4 shadow-lg" : "hidden"} md:static md:block md:border-0 md:p-0 md:shadow-none`} id="public-navigation">
      <ul className="flex flex-col gap-1 text-sm font-semibold md:flex-row md:flex-wrap md:items-center md:justify-end md:gap-3">
        {links.map(([label, href]) => <li key={href}><Link className="block rounded px-3 py-2 no-underline hover:bg-violet-50 hover:underline" href={href} onClick={() => setOpen(false)}>{label}</Link></li>)}
        <li className="mt-2 md:mt-0"><Link className="primary-cta inline-flex min-h-11 items-center justify-center rounded px-3 no-underline" href="/admissions" onClick={() => setOpen(false)}>Register now</Link></li>
        <li><Link className="inline-flex min-h-11 items-center justify-center rounded border-2 border-violet-800 px-3 text-violet-950 no-underline" href="/login" onClick={() => setOpen(false)}>School login</Link></li>
      </ul>
    </nav>
  </div>;
}
