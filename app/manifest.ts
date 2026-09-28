import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "Little Gems Private School",
    short_name: "Little Gems",
    description: "Little Gems Private School — Winning From The Start.",
    start_url: "/",
    display: "standalone",
    background_color: "#ffffff",
    theme_color: "#5b0b7a",
    icons: [
      { src: "/icons/icon-192.png", sizes: "192x192", type: "image/png", purpose: "any" },
      { src: "/icons/icon-512.png", sizes: "512x512", type: "image/png", purpose: "any" },
      { src: "/icons/icon-512-maskable.png", sizes: "512x512", type: "image/png", purpose: "maskable" },
    ],
  };
}
