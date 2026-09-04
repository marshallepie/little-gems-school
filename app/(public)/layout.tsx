import { PublicFooter, PublicHeader } from "@/components/public-site";

export default function PublicLayout({ children }: Readonly<{ children: React.ReactNode }>) { return <><PublicHeader />{children}<PublicFooter /></>; }
