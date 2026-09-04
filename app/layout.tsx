import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: { default: "Little Gems Private School", template: "%s | Little Gems Private School" },
  description: "Little Gems Private School — Winning From The Start.",
  openGraph: { type: "website", siteName: "Little Gems Private School", title: "Little Gems Private School", description: "Winning From The Start." },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body className="min-h-screen">{children}</body></html>;
}
