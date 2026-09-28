import type { Metadata, Viewport } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: { default: "Little Gems Private School", template: "%s | Little Gems Private School" },
  description: "Little Gems Private School — Winning From The Start.",
  openGraph: { type: "website", siteName: "Little Gems Private School", title: "Little Gems Private School", description: "Winning From The Start." },
  manifest: "/manifest.webmanifest",
  icons: {
    icon: [{ url: "/favicon.ico", sizes: "32x32", type: "image/x-icon" }],
    shortcut: ["/favicon.ico"],
    apple: [{ url: "/apple-icon.png", sizes: "180x180", type: "image/png" }],
  },
};

export const viewport: Viewport = {
  themeColor: "#5b0b7a",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body className="min-h-screen">{children}</body></html>;
}
