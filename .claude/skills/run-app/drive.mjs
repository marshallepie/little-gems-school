// Drives the Little Gems School app in a real browser. See SKILL.md step 7.
// Must be run from the project root so `playwright` resolves.
import { chromium } from "playwright";

const BASE = process.env.BASE_URL ?? "http://localhost:3000";
const EMAIL = process.env.TEST_EMAIL ?? "admin@local.test";
const PASSWORD = process.env.TEST_PASSWORD ?? "LocalTest123!";

const browser = await chromium.launch();
// Mobile-first surface, so drive it at a phone width.
const page = await browser.newPage({ viewport: { width: 420, height: 900 } });
const errors = [];
page.on("console", (m) => m.type() === "error" && errors.push(m.text()));

const banners = () =>
  page.locator('[role="status"], [role="alert"]').allInnerTexts().then((t) => t.join(" | ") || "(none)");

// 1. Public pages render.
await page.goto(BASE, { waitUntil: "networkidle" });
console.log("[home] title:", await page.title());
await page.screenshot({ path: "/tmp/lgs-1-home.png", fullPage: true });

// 2. Protected routes bounce to login while signed out.
for (const path of ["/dashboard", "/admin"]) {
  await page.goto(`${BASE}${path}`, { waitUntil: "networkidle" });
  console.log(`[signed out] ${path} ->`, new URL(page.url()).pathname);
}

// 3. A wrong password is rejected and creates no session.
await page.goto(`${BASE}/login`, { waitUntil: "networkidle" });
await page.screenshot({ path: "/tmp/lgs-2-login.png", fullPage: true });
await page.fill('input[type="email"]', EMAIL);
await page.fill('input[type="password"]', "WrongPassword1!");
await page.click('button[type="submit"]');
await page.waitForTimeout(2500);
console.log("[bad login] url:", new URL(page.url()).pathname, "| notice:", await banners());
await page.screenshot({ path: "/tmp/lgs-3-bad-login.png", fullPage: true });

// 4. The real password reaches the role surface.
// The form action resets BOTH fields after a failure, so refill email too.
await page.fill('input[type="email"]', EMAIL);
await page.fill('input[type="password"]', PASSWORD);
await page.click('button[type="submit"]');
await page.waitForURL(/\/(admin|dashboard|teacher|parent|student)/, { timeout: 20000 }).catch(() => {});
await page.waitForLoadState("networkidle");
console.log("[good login] url:", new URL(page.url()).pathname);
console.log("[good login] h1:", await page.locator("h1").first().innerText().catch(() => "(none)"));
await page.screenshot({ path: "/tmp/lgs-4-admin.png", fullPage: true });

// 5. Write a record through the admin Student form and confirm it comes back.
const form = page.locator("section", { hasText: "Student" }).first();
const admissionNumber = `LG-${Date.now().toString().slice(-6)}`;
await form.locator('input[name="admission_number"]').fill(admissionNumber);
await form.locator('input[name="first_name"]').fill("Testy");
await form.locator('input[name="last_name"]').fill("Runcheck");
await form.locator('select[name="status"]').selectOption("active");
await form.locator('button[type="submit"]').click();
await page.waitForLoadState("networkidle");
await page.waitForTimeout(1500);
console.log("[create student] url:", page.url(), "| banner:", await banners());
const recent = await page.locator("section", { hasText: "Recent records" }).innerText().catch(() => "");
console.log("[create student] appears in Recent records:", recent.includes(admissionNumber));
await page.screenshot({ path: "/tmp/lgs-5-after-create.png", fullPage: true });

// A 400 here is expected: Supabase returns 400 for the deliberate bad login.
console.log("console errors:", errors.length ? errors.slice(0, 5) : "none");
console.log(`\nCreated test student ${admissionNumber}. Remove it with:\n` +
  `  docker exec supabase_db_little-gems-school psql -U postgres -d postgres -c "delete from public.students where last_name='Runcheck';"`);
await browser.close();
