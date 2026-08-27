import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Little Gems School",
  description: "Little Gems School portal foundation",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body className="mx-auto min-h-screen max-w-5xl px-6 py-10">{children}</body></html>;
}
