import Link from "next/link";
import { PublicPage } from "@/components/public-site";
import { getPublishedNews } from "@/lib/public-content";
export const metadata = { title: "News | Little Gems Private School", description: "Latest news and announcements from Little Gems Private School." };
export const revalidate = 300;
export default async function NewsPage() { const posts = await getPublishedNews(); return <PublicPage eyebrow="News" title="School news and announcements"><section className="mt-8 max-w-3xl space-y-4">{posts.length ? posts.map((post) => <article className="rounded-xl border bg-white p-6" key={post.id}><h2 className="text-xl font-bold"><Link href={`/news/${post.slug}` as never}>{post.title}</Link></h2>{post.published_at && <p className="mt-1 text-sm text-slate-600">{new Intl.DateTimeFormat("en", { dateStyle: "long" }).format(new Date(post.published_at))}</p>}<p className="mt-3">{post.excerpt}</p></article>) : <p className="rounded border border-dashed p-5 text-slate-700">Published school news will appear here.</p>}</section></PublicPage>; }
