"use client";

import { useState } from "react";

type AuthFormProps = { title: string; description: string; buttonLabel: string; password?: boolean };

export function AuthForm({ title, description, buttonLabel, password = false }: AuthFormProps) {
  const [notice, setNotice] = useState<string | null>(null);
  return <main className="mx-auto max-w-md space-y-6"><h1 className="text-3xl font-bold">{title}</h1><p>{description}</p><form className="space-y-4" onSubmit={(event) => { event.preventDefault(); setNotice("Authentication is not configured yet. Follow the local setup instructions in README.md."); }}><label className="block font-medium">Email<input className="mt-1 w-full rounded border p-2" type="email" required autoComplete="email" /></label>{password && <label className="block font-medium">Password<input className="mt-1 w-full rounded border p-2" type="password" required autoComplete="current-password" /></label>}<button className="rounded bg-violet-700 px-4 py-2 font-semibold text-white" type="submit">{buttonLabel}</button></form>{notice && <p className="rounded border border-amber-300 bg-amber-50 p-3" role="status">{notice}</p>}</main>;
}
