# SUPERSEDED — Little Gems School Portal — Milestone 0 Technical Discovery Report

> **Status:** This 2026-08-26 Gibbon research is retained as historic decision evidence only. It is superseded by the Native Next.js + Supabase direction in [`PRD.md`](PRD.md) and the implementation-ready [`native-nextjs-supabase-architecture-spike.md`](native-nextjs-supabase-architecture-spike.md). It must not be used to begin Gibbon, PHP, WordPress, Docker/Gibbon, or MySQL implementation.

---

# Little Gems School Portal — Milestone 0 Technical Discovery Report
## Gibbon School Management Platform Technical Spike

**Prepared for:** Little Gems Private School, Nigeria  
**Prepared by:** Hermes Agent (Technical Discovery Subagent)  
**Date:** 2026-08-26  
**Status:** Complete — Ready for Architecture Decision

---

## Executive Summary

Gibbon is a mature, actively maintained, GPL-licensed open source school management platform written in PHP. It has a theme system, module/plugin architecture, and dashboard hooks. It does **not** expose a public REST or GraphQL API. The recommended architecture for Little Gems is a **custom Gibbon theme + a custom Gibbon module** for simplified dashboards, plus a **separate static/server-side public website** that can be updated by non-technical staff — all sitting in front of a stock Gibbon backend that is never modified at core level.

---

## Research Methodology

Sources consulted:
- https://gibbonedu.org (official site)
- https://github.com/GibbonEdu/core (source repository, v30/v31 branches)
- https://github.com/GibbonEdu/core/releases (release history)
- https://docs.gibbonedu.org (official documentation)
- https://ask.gibbonedu.org (community forums — several threads)
- https://gibbonedu.org/extend (module/theme extension page)
- https://hub.docker.com + GitHub for Docker images
- https://gibbonedu.org/license/ (licensing page)

---

## Area 1: Current Stable Version and Release Cadence

**Findings:**
- Latest stable release: **v30.0.01 "Nam Chung"** (released 6 February 2026)
- v31.0.00 branch is actively being developed on GitHub (commits as recently as August 2026) — **not yet released publicly as stable**
- Release cadence: **twice per year**, targeting **November and April** since v26 onwards (adjusted from the previous January/June cycle)
- Patch releases (e.g. v30.0.01) are issued only for security concerns or significant bugs
- Gibbon has 55 releases over approximately 15 years of development
- The project is governed by the **Gibbon Foundation**, a non-profit

**Caveats:**
- v31 is in active development on GitHub (the default branch is `v31.0.00`) but no public release yet as of the spike date

**Architecture impact:**
- The November 2026 release cycle (v31) is likely during project development. Build with upgrades in mind from day one.

---

## Area 2: Installation Requirements (PHP, Web Server, OS)

**Findings:**
- **Language:** PHP (minimum **8.0**, recommended up to **8.3**)
- **Web server:** Apache 2 or Nginx (Apache with `mod_rewrite` is the standard documented path)
- **Database:** MySQL **8.0** minimum (or compatible MariaDB)
- **Required PHP extensions:** `gettext`, `mbstring`, `curl`, `zip`, `xml`, `gd`, `intl`, `pdo`, `pdo_mysql`
- **OS:** Primarily Linux (Ubuntu/Debian documented); also macOS and Windows for local dev
- **Dependency manager:** Composer (required only for cutting-edge/dev code; stable releases include the vendor folder)
- **HTTPS:** Required for production; certbot/Let's Encrypt documented
- Storage: Gibbon stores uploaded files in an `/uploads/` directory on the server

**Caveats:**
- The system requirements page does not specify exact RAM/CPU — these scale with user count
- MariaDB compatibility is generally maintained but not the primary tested database

**Architecture impact:**
- Standard LAMP/LEMP stack. Containerising is straightforward. No exotic runtime dependencies.

---

## Area 3: Docker/Container Deployment Options

**Findings:**
- **Official Docker support:** Gibbon's own GitHub repo (`GibbonEdu/core`) includes a Docker setup in the `ops/` directory, added in June 2026 (PR #2077). This is currently scoped for **developer use** (local development), not a hardened production image.
- **Community Docker images** (third-party, not official):
  1. **matiaspagano/gibbon-docker** — Reasonably complete, supports env vars for auto-install (`GIBBON_AUTOINSTALL=1`), configurable system name, timezone, country, currency. Covers up to v24. May be behind current version.
  2. **PaulLebmann/docker-gibbonedu** — Apache + PHP-FPM setup with Nginx reverse proxy integration, backup support. Designed for production. Requires manual Gibbon web installer.
  3. **kerrongordon/gibbon** — Simpler, labelled "demo use only", Docker Compose with MySQL.
- No official Docker Hub image exists from GibbonEdu

**Caveats:**
- All community Docker images are third-party and lag behind the latest Gibbon release
- No production-quality official Docker image exists — the project will need to build its own
- The official `ops/` Docker setup uses `./up.sh` script and exposes Gibbon on port 8080

**Architecture impact:**
- **The project should build a custom Docker Compose stack** based on the official dev setup but hardened for production: PHP-Apache container + MySQL container + Nginx reverse proxy. This is well-trodden territory and not high risk.

---

## Area 4: Database Requirements (MySQL/MariaDB, Schema Overview)

**Findings:**
- **Database:** MySQL 8.0 minimum; `utf8mb3_general_ci` collation
- **Schema:** All tables use the `gibbon` prefix (e.g. `gibbonPerson`, `gibbonFamily`, `gibbonCourse`)
- Key tables visible from SQL documentation and code:
  - `gibbonPerson` — All users (students, parents, staff, admins share this table with role differentiation)
  - `gibbonRole` — Role definitions
  - `gibbonStudentEnrolment` — Student enrollment per school year
  - `gibbonFamily` — Family unit
  - `gibbonFamilyChild` — Links students to families
  - `gibbonFamilyAdult` — Links parents/guardians to families
  - `gibbonStaff` — Staff records (extension of gibbonPerson)
  - `gibbonCourse` — Courses/subjects
  - `gibbonCourseClass` — Class groups within courses
  - `gibbonCourseClassPerson` — Enrolment of persons into classes
  - `gibbonAttendanceLogPerson` — Attendance records per person
  - `gibbonSchoolYear` — Academic years
  - `gibbonTTColumn`, `gibbonTTDay`, `gibbonTT` — Timetable structure
  - `gibbonMarkbookColumn`, `gibbonMarkbookEntry` — Gradebook
  - `gibbonPlannerEntry` — Lesson plans (also used for homework via `homeworkDueDate`, `viewableStudents`, `viewableParents` fields)
  - `gibbonHook` — Module hook registrations
  - `gibbonModule`, `gibbonAction`, `gibbonPermission` — Module/permissions system
  - `gibbonSetting` — Global settings key-value store

**Caveats:**
- The full schema is large (100+ tables); the above are the core entities relevant to this project
- Schema changes between versions are managed via `CHANGEDB.php` in each module

**Architecture impact:**
- The data model cleanly separates students, families, and staff as linked entities. Parent-to-child relationships via `gibbonFamily` are central to authorisation logic.

---

## Area 5: Theme/Branding Capabilities

**Findings:**
- Gibbon has a **built-in theming system**. Themes live in `/themes/<ThemeName>/` within the Gibbon installation
- Themes can be installed/activated via **System Admin → Manage Themes**
- A theme can contain:
  - CSS files for visual override
  - Template overrides (HTML/PHP Twig-like templates) — placed in `themes/<ThemeName>/templates/` — these override equivalent core templates
  - Images, fonts
- The default theme is `Default`. A custom theme named `LittleGems` would live at `/themes/LittleGems/`
- **Display Settings** (System Admin → Display Settings) allow: logo upload, colour selection from the theme's defined palette, background image
- **String Replacement** (System Admin → String Replacement) allows renaming Gibbon's UI terms (e.g. rename "Markbook" to "Results") without code changes
- Since v28 (November 2024), the frontend was **refreshed to use HTMX and Alpine.js** — replacing jQuery. CSS custom theming must target the new frontend

**Caveats:**
- Theming is limited to visual styling and template overrides — it cannot change navigation structure or hide/show modules by role without also using the permissions system
- There is no documented "blank" or "child" theme starter; community threads suggest copying the Default theme as a starting point
- The extent of white-labelling is: full visual rebrand (logo, colours, typography, imagery) ✅ — but Gibbon UI chrome (menus, module names) will still be visible unless additionally suppressed via a custom module/permissions config
- A custom theme folder lives **outside core**, so it survives upgrades

**Architecture impact:**
- Theming alone cannot deliver the "simplified role dashboard" experience described in the PRD. Theming handles visual identity; a custom module handles simplified navigation/content per role.

---

## Area 6: Module/Plugin Architecture

**Findings:**
- Gibbon has a first-class **module system**. Modules are self-contained folders within `/modules/`
- A module can define:
  - Actions (fine-grained capabilities)
  - Permissions (which roles can access which actions)
  - Custom database tables via `CHANGEDB.php`
  - CSS (`css/module.css`) and JS (`js/module.js`) that are auto-loaded
  - PHP functions (`moduleFunctions.php`)
  - Pages (`index.php`, additional PHP files)
  - Domain gateway classes (`src/Domain/`)
- Modules can be installed/uninstalled via **System Admin → Manage Modules**
- **Starter module:** https://github.com/GibbonEdu/module-gibbonStarterModule — fork and build from this
- Modules can be proprietary (licence replaced) — the starter module says "Remove or replace the GNU GPL statement depending on your needs"

**Dashboard Hooks (critical for Little Gems):**
The core provides **5 hook points** that custom modules can inject into:
1. **Parent Dashboard** — inject content into parent home page
2. **Student Dashboard** — inject content into student home page
3. **Staff Dashboard** — inject content into staff/teacher home page
4. **Public Home Page** — inject content into the logged-out public page
5. **Student Profile** — inject additional data panels into the student profile view

A custom module registers a hook in its `manifest.php` by writing to `gibbonHook`. The hook specifies which PHP file to include, and that file renders arbitrary HTML into the dashboard.

**Community evidence:**
- A community developer successfully built a full "Homework Calendar" module without touching core, using dashboard hooks for student/parent views, in January 2026. This demonstrates the hook system works for complex custom views.

**Caveats:**
- Modules live in `/modules/` — this is **inside the Gibbon directory** and could be overwritten on a naive upgrade if not versioned separately. **Solution:** Git-manage the custom module or use Docker volumes to persist it across upgrades
- The hook system covers dashboards but not every page — custom navigation or restructuring beyond dashboards requires theme template overrides

**Architecture impact:**
- The simplified role dashboard experience for Little Gems **can be built entirely as a custom Gibbon module** using dashboard hooks — no core modification required. This is the confirmed safe path.

---

## Area 7: Available APIs or Integration Interfaces

**Findings:**
- Gibbon does **not** have a documented public REST API, GraphQL API, or webhook system
- There is no formal API endpoint layer (no `/api/v1/...` routes)
- Data access for external systems must be done by one of:
  1. **Direct database access** — read the MySQL database directly (read-only is safe; write requires understanding the schema thoroughly)
  2. **CLI tools** — Gibbon has command-line scripts in `/cli/` for scheduled tasks
  3. **Custom module that exposes an endpoint** — a custom module could create PHP pages that return JSON, effectively building a lightweight API layer
  4. **Session-based scraping** — not recommended
- The Feed module (https://github.com/GibbonEdu/module-feed) suggests some RSS/feed capability exists
- Google and Microsoft integrations (calendar sync, OAuth login) are documented but are point-to-point integrations, not a general API

**Caveats:**
- The absence of a REST API is the single biggest architectural constraint. A separate SPA frontend consuming Gibbon data via API is **not a supported pattern** without building that API layer yourself.
- Any custom API layer must run as a Gibbon module (so it benefits from Gibbon's session authentication) or sit separately with direct DB access (which bypasses Gibbon's permission model — dangerous)

**Architecture impact:**
- **A headless architecture (separate SPA + Gibbon API) is not viable without significant custom backend work.** The recommended approach is to customise within Gibbon's own PHP rendering pipeline (theme + module), not to build a decoupled frontend.

---

## Area 8: Authentication Architecture

**Findings:**
- Gibbon uses **PHP session-based authentication** — users log in via a web form; a PHP session is created
- **Password storage:** Gibbon uses bcrypt/PHP `password_hash()` — passwords are never stored in plaintext
- **Multi-role support:** Users can have multiple roles and switch between them using a "Role Switcher" on the dashboard
- **Google OAuth integration:** Documented; users can authenticate via Google accounts (linked to their Gibbon user)
- **Microsoft integration:** Documented
- **LDAP:** Not natively documented in current docs (may exist via community modules)
- **JWT/token-based auth:** Not natively supported
- **SSO (SAML):** Not natively supported
- The login page is `/login.php`. There is a `logout.php`.

**Caveats:**
- No native OAuth server (Gibbon cannot act as an identity provider)
- Google/Microsoft OAuth is for authentication into Gibbon, not for Gibbon to act as IdP for another app
- For Little Gems, standard Gibbon session auth is sufficient for MVP

**Architecture impact:**
- Authentication is standard session-based PHP. This is fine for the portal pattern (all users authenticate to one Gibbon instance). If future plans include a mobile app or external SPA, a token-based auth layer would need to be added as a custom module.

---

## Area 9: Role/Permission Model

**Findings:**
- Gibbon ships with **5 default roles:**
  1. Administrator
  2. Teacher
  3. Student
  4. Parent
  5. Support Staff
- Additional custom roles can be created (e.g. "Student Extended", "Head of Department")
- **Users can have multiple roles** and switch between them at runtime (Role Switcher)
- **Permissions** are managed at **Admin > User Admin > Manage Permissions**
- Permissions are at the level of **module → action** — each action within each module can be switched on or off per role
- Permission model is **additive** — you grant access; default is deny
- Family relationships control parent access to student data: a parent can only see their child's information through the `gibbonFamily` → `gibbonFamilyChild` relationship
- Permission granularity examples:
  - "Take Attendance (all classes)" vs "Take Attendance (own classes only)"
  - "View Student Profile (brief)" vs "View Student Profile (full)"
  - Parents can be restricted to "brief" profile view

**Caveats:**
- Permissions control access to module actions, not to specific data rows (that is handled by family/enrolment relationships). Row-level security is implemented in PHP logic per page, not at DB level.
- The permissions system is quite mature and flexible, but requires careful initial configuration audit

**Architecture impact:**
- Gibbon's role/permission system maps cleanly onto the PRD requirements. The Little Gems approach should: (a) configure permissions to restrict each role to only what they need, and (b) use a custom module with dashboard hooks to present a simplified UI — hiding the rest of Gibbon's menus via CSS/theme or permission removal.

---

## Area 10: Student/Parent/Teacher Data Model

**Findings:**
All users (students, parents, teachers, admins) are stored in `gibbonPerson`. Role differentiation is via `gibbonRoleIDPrimary` and the `gibbonRole` table.

Key entity relationships:
```
gibbonPerson (all users)
  ├── gibbonStaff  (teachers/staff extension)
  ├── gibbonStudentEnrolment → gibbonYearGroup, gibbonRollGroup, gibbonSchoolYear
  ├── gibbonFamilyChild → gibbonFamily
  └── gibbonFamilyAdult → gibbonFamily (parents link here)

gibbonFamily
  ├── gibbonFamilyChild (links to student persons)
  └── gibbonFamilyAdult (links to parent persons, with contactPriority 1/2)

gibbonCourse → gibbonCourseClass → gibbonCourseClassPerson (students AND teachers)
gibbonTT (timetable) → gibbonTTDay → gibbonTTColumn (structure)
gibbonPlannerEntry (lesson plans + homework via homeworkDueDate, viewableStudents, viewableParents)
gibbonMarkbookColumn → gibbonMarkbookEntry (per student grades)
gibbonAttendanceLogPerson (attendance records per day, with type and reason)
```

Student Profile pulls together: attendance, markbook, timetable, planner/homework, individual needs, library borrowing, formal assessments, reports.

**Caveats:**
- The data model is mature and well-normalised; foreign keys are used
- Understanding this model is necessary before any direct DB integration

**Architecture impact:**
- The data model supports all PRD requirements natively (student info, parent relationships, classes, timetable, attendance, homework, grades). No custom tables are needed for basic functionality.

---

## Area 11: Attendance Capabilities

**Findings:**
- Native attendance module is core, not an add-on
- **Methods:**
  - Form/roll group attendance (daily morning attendance by tutor/homeroom teacher)
  - Class/lesson attendance (per-lesson within the Planner)
  - Future absence pre-entry (known absences can be set in advance)
- Attendance records include: type (present, absent, late, etc.), reason, comment
- **Viewing:**
  - Teachers can view attendance for their classes and form groups
  - Admins can review attendance across the whole school
  - Parents can view their child's attendance (controllable by permission)
  - Student profile shows full attendance history with absence patterns
- Absence reports can be generated for emergency evacuation purposes
- Comparison between school attendance and class attendance is supported

**Caveats:**
- The level of configurability of absence types/reasons requires initial setup
- No QR code or biometric attendance capture natively (PRD lists biometric as out-of-scope, so this is fine)

**Architecture impact:**
- Attendance capability is comprehensive and maps to all PRD requirements. No custom development needed.

---

## Area 12: Timetable Capabilities

**Findings:**
- Native timetable module is core
- Gibbon timetable uses a **non-grid-restrained approach**: define Columns (period structures for a day), then Days, then attach Days to calendar dates
- Supports multiple timetables per school year (e.g. Primary and Secondary may have different structures)
- A year group can belong to only one timetable
- Timetable displays: individual student timetable, individual teacher timetable, room bookings
- v29 (May 2025) featured a redesigned timetable UI with quick-toggle layers and improved visual presentation
- v30 (November 2025) added Calendar module integration with timetable
- Google Calendar linking is supported

**Caveats:**
- Timetable setup is complex — requires: school year, terms, days, columns, rows, courses, classes, enrolment. One-time setup with admin support
- The timetable system is powerful but data-entry-heavy; a Nigerian school may need staff training

**Architecture impact:**
- Full timetable capability native. Parents and students can view read-only timetables via permissions.

---

## Area 13: Assignment/Homework Capabilities

**Findings:**
- Homework is part of the **Planner module**, not a standalone homework module
- Teachers create **Lesson Plans** with a `homeworkDueDate` and control visibility via `viewableStudents` and `viewableParents` flags
- Students can **submit work online** through the Planner (file uploads, text responses)
- Submitted work can be linked to a **Markbook column** for grading
- Parents can view homework if `viewableParents` is enabled on the lesson plan
- A community module (**Homework Calendar** / **Academic Calendar**) was developed in January 2026 and released on GitHub — provides a visual calendar view of deadlines for students, parents, and teachers without touching core

**Caveats:**
- Homework is tightly coupled to lesson plans — a teacher must create a lesson plan to set homework. This is more complex than a simple "create homework task" workflow
- The default Gibbon homework view is timetable-centric, which may be less intuitive for parents. The community Homework Calendar module addresses this.

**Architecture impact:**
- Basic homework works natively. For a parent-friendly homework view (PRD requirement), the community Homework Calendar module should be evaluated for inclusion. The module demonstrates the hook system can support this without core modification.

---

## Area 14: Assessment/Reporting Capabilities

**Findings:**
- **Markbook:** Continuous gradebook. Teachers enter grades per column (assignment/assessment). Configurable per school. Can be made visible to students and parents independently
- **Rubrics:** Clickable rubrics, integrated with outcomes and planner
- **Formal Assessment:** Internal and External assessments (e.g. exam results). Can be added with no programming
- **Tracking:** Graphs markbook + assessment data over time; export to spreadsheet
- **Reports module:** Full report card generation system with template builder, reporting cycles, proof-reading workflow, publishing. Parents can view published reports
- **Crowd Assessment:** Peer assessment system
- Permission control: Teachers enter grades, admins publish/approve, parents/students only see released content

**Caveats:**
- The Reports module is sophisticated but has a notable setup curve (templates, reporting cycles, etc.)
- Markbook visibility to parents is controlled per-column (teachers must explicitly enable it)
- Assessment entry by teachers works within Gibbon's own UI — there is no API for external grade entry

**Architecture impact:**
- Assessment and reporting is comprehensive. PRD requirements (teacher entry, parent/student view of released results) are covered natively. No custom development required for basic assessment.

---

## Area 15: Public Website/Content Capabilities

**Findings:**
- Gibbon has a **Public Home Page** — a simple landing page visible to logged-out users
- The public home page can be extended via the **Public Home Page hook** (modules can inject sections into it)
- This is **not** a CMS — it is a static PHP-rendered page with hook-injectable sections
- There is a public **Application Form** (admissions) that members of the public can submit
- Beyond the home page, public-facing content in Gibbon is minimal — it's not designed as a website CMS
- There is no page builder, no content types, no blog/news management system

**Caveats:**
- Gibbon's public home page is **insufficient** for the PRD's public website requirements (Home, About, Admissions, Academics, News, Calendar, Contact pages)
- The Messenger module provides a "Message Wall" for internal announcements, not a public news feed

**Architecture impact:**
- **A separate public website is required.** This is a clear gap. Options: (a) a static site generator (Hugo, 11ty, Next.js) with a simple admin editing workflow, (b) a lightweight CMS (WordPress, Ghost, Strapi) running alongside Gibbon, or (c) a hand-coded HTML/CSS site for MVP (not recommended — content won't be editable without code). The public site can link to the Gibbon login page for authenticated access. The PRD requirement that "content must be manageable without developers" rules out a static file approach without a CMS layer.

---

## Area 16: Supported Methods for Creating a Custom Frontend

**Findings:**
Three broad approaches exist:

**Option A: Gibbon Theme Override (Recommended primary approach)**
- Create a custom theme in `/themes/LittleGems/`
- Override template files to change navigation, layout, and visual design
- Add custom CSS, JS (HTMX/Alpine.js compatible from v28+)
- Combined with the permissions system to hide unwanted modules
- Lives outside core — survives upgrades ✅

**Option B: Custom Gibbon Module with Dashboard Hooks**
- Create a module that hooks into Parent Dashboard, Student Dashboard, Staff Dashboard
- Inject simplified, role-specific content panels
- Register custom menu items visible only to specific roles
- Lives outside core — survives upgrades ✅
- Community-proven (Homework Calendar module example)

**Option C: Separate SPA/Frontend Consuming Gibbon Data**
- No native API — would require building a custom API layer (as a Gibbon module or alongside it)
- Complex to implement and maintain
- Session auth doesn't translate cleanly to token-based SPA auth without additional work
- Not recommended for MVP

**Option D: Hybrid (A + B)**
- Custom theme for visual identity + custom module for simplified dashboards
- This is the **recommended approach** — all within Gibbon, no core modification needed

**Caveats:**
- Gibbon uses HTMX + Alpine.js since v28 — custom JS should be compatible with this
- Template overrides in a theme must be carefully reviewed on each Gibbon upgrade

---

## Area 17: Upgrade Implications of Each Customisation Approach

| Approach | Upgrade Safety | Notes |
|---|---|---|
| Custom theme in `/themes/LittleGems/` | ✅ High | Lives outside core, survives upgrades |
| Template overrides in theme | ⚠️ Medium | Must review on each upgrade — core templates may change |
| Custom module in `/modules/LittleGems/` | ✅ High | Lives outside core, survives upgrades |
| Module dashboard hooks | ✅ High | Hook API is stable; unlikely to break |
| Permission configuration (via admin UI) | ✅ High | DB-stored, survives upgrades |
| String replacements (System Admin) | ✅ High | DB-stored, survives upgrades |
| Direct core file edits | ❌ None | Overwritten on upgrade — never do this |
| Direct DB writes to core tables | ⚠️ Medium | Schema changes between versions may break custom queries |
| Separate public website (external) | ✅ High | Fully independent — no Gibbon coupling |

**Key risk:** Template overrides in the theme folder need a **review step** on each Gibbon release. The project's upgrade procedure should include: diff the changed core templates against the overridden versions in the custom theme.

---

## Area 18: Licensing/White-Label Requirements

**Findings:**
- Gibbon is licensed under **GNU General Public License v3.0 (GPL-3.0)**
- The copyright is held by Ross Parker
- GPL v3 permits: use, modification, redistribution (including commercially)
- GPL v3 requires: if you distribute modified source, you must provide source code under GPL v3; derivative works must also be GPL v3

**For Little Gems specifically:**
- Running Gibbon on a private school's server for that school's internal use: **no distribution obligation arises** — GPL copyleft is triggered only when you distribute software to third parties
- The Little Gems implementation does NOT distribute Gibbon to third parties — it is hosted and used by one school
- Therefore: **no obligation to open-source the custom Little Gems theme or modules**
- White-labelling (removing Gibbon branding from the user interface): **legally permitted under GPL v3** for private use
- The PRD requirement to remove "prominent Gibbon branding" from the normal user experience is **legally permissible**

**Attribution:**
- The license page states: "The Gibbon name, logo and code base are © 2011 Ross Parker"
- In practice, many schools run completely white-labelled Gibbon instances with no visible Gibbon branding
- Best practice: retain a footer credit or about-page mention; this is not legally required for private use but is good open-source citizenship

**Caveats:**
- If Little Gems were ever to sell or redistribute the Little Gems portal software to other schools (making it a product), GPL obligations would apply to the Gibbon core portions
- Custom modules and themes can be licensed under any licence when kept private

**Architecture impact:**
- White-labelling is legally unambiguous for private school use. Full brand replacement (logo, colours, name, favicon) with no Gibbon branding in the user experience is permitted.

---

## Area 19: Recommended Little Gems Architecture

### Recommended Approach: Gibbon Theme + Custom Module + External Public Website

```
Public Internet
     |
     ├── [1] Little Gems Public Website (separate)
     │       Static or CMS-driven (e.g. Next.js + headless CMS, or WordPress)
     │       Pages: Home, About, Admissions, Academics, News, Calendar, Contact, Login
     │       → Login button links to Gibbon instance
     |
     └── [2] Little Gems Gibbon Instance
             Domain: portal.littlegems.edu.ng (or similar)
             
             ┌─────────────────────────────────────────────────────┐
             │  Nginx reverse proxy (SSL/TLS termination)          │
             └───────────────────┬─────────────────────────────────┘
                                 │
             ┌───────────────────▼─────────────────────────────────┐
             │  PHP-Apache container (Gibbon v30+)                 │
             │  /themes/LittleGems/    ← custom theme (Git-managed)│
             │  /modules/LittleGems/  ← custom module (Git-managed)│
             └───────────────────┬─────────────────────────────────┘
                                 │
             ┌───────────────────▼─────────────────────────────────┐
             │  MySQL 8.0 container                                │
             │  Gibbon database (all school data)                  │
             └─────────────────────────────────────────────────────┘

Docker Compose manages all three containers.
Nginx serves SSL via certbot/Let's Encrypt.
```

### What the Custom Theme Provides:
- Little Gems logo, colours, fonts (replacing Gibbon defaults)
- Mobile-first responsive CSS
- No Gibbon branding visible in normal user flow
- Simplified navigation template that hides unneeded Gibbon menus

### What the Custom Module Provides:
- Simplified Dashboard hooks for each role (Admin, Teacher, Parent, Student)
- Each dashboard shows only the 5–8 most relevant widgets for that role
- Simplified navigation links within the module
- Parent dashboard: child selector → attendance/homework/results/announcements
- Student dashboard: timetable/homework/results/announcements
- Teacher dashboard: my classes/attendance/planner/markbook
- Admin dashboard: key stats + links to Gibbon admin areas

### What Gibbon Core Provides (unchanged):
- All data management (users, enrolment, classes, timetable, attendance, markbook, reports)
- Permission enforcement (server-side, role-based)
- Session authentication
- Admin tools (full Gibbon admin area, accessible to Admins only)
- Teacher tools (attendance, planner, markbook — accessible via simplified links from the custom dashboard)

### What the External Public Website Provides:
- Branded public presence
- CMS-managed content pages (Home, About, Admissions, Academics, News)
- School calendar/events (can pull from Gibbon or be managed separately for MVP)
- Contact page
- Login button linking to Gibbon portal

**Smallest viable public website for MVP:** A single-page or multi-page site built with Next.js (static export) or plain HTML/CSS + a simple CMS (Netlify CMS, TinaCMS, or WordPress as headless CMS for non-technical content management).

---

## Area 20: Major Risks and Functionality Gaps

### 🔴 Critical Risks

| Risk | Description | Mitigation |
|---|---|---|
| **No REST API** | Gibbon has no public API; headless pattern not viable | Build within Gibbon's PHP pipeline; use direct DB access only for read-only reporting |
| **No CMS / Public Website** | Gibbon cannot manage a public website with multiple pages | Build a separate public website; plan its hosting and content workflow |
| **Theme upgrade fragility** | Template overrides in theme may break on Gibbon releases | Document all overrides; include a theme review step in the upgrade procedure |

### 🟡 Medium Risks

| Risk | Description | Mitigation |
|---|---|---|
| **Docker production gap** | No official production Docker image; community images lag | Build a custom Docker Compose stack — well-documented territory |
| **Homework UX for parents** | Default homework view is timetable-centric, not parent-friendly | Evaluate and adopt community Homework Calendar module; or build simplified view in custom module |
| **Timetable data entry complexity** | Timetable setup is multi-step and complex | Plan a dedicated admin onboarding/setup phase (Milestone 2); provide documentation |
| **Module version drift** | Custom module must track Gibbon API changes | Pin custom module to Gibbon version; test after each upgrade |
| **Mobile usability of stock Gibbon** | Gibbon's default UI, while improved in v28, is not mobile-first | Custom theme must prioritise mobile CSS; test on real devices throughout |

### 🟢 Confirmed Native Capabilities (No Gaps for PRD)

| PRD Requirement | Status |
|---|---|
| Student information management | ✅ Native |
| Parent-child relationship & authorisation | ✅ Native (gibbonFamily) |
| Role-based access control | ✅ Native (configurable) |
| Teacher attendance recording | ✅ Native |
| Student/parent attendance viewing | ✅ Native (with permissions) |
| Timetable viewing | ✅ Native |
| Homework/assignment creation | ✅ Native (via Planner) |
| Homework viewing by parents/students | ✅ Native (with permissions) |
| Assessment/markbook entry by teachers | ✅ Native |
| Assessment viewing by parents/students | ✅ Native (when published/enabled) |
| Report cards | ✅ Native (Reports module) |
| School announcements (internal, via Message Wall) | ✅ Native (Messenger module) |
| School calendar / events | ✅ Native (Calendar module, v30+) |
| Document sharing | ✅ Native (Resources module) |
| White-labelled branding | ✅ Legally permitted, technically feasible |
| Containerisation | ✅ Feasible (custom Docker Compose) |
| User bulk import | ✅ Native (CSV import in System Admin) |

### ❌ What Gibbon Cannot Do Natively (Gaps Requiring Separate Solutions)

| Requirement | Gap | Solution |
|---|---|---|
| Public website with multiple managed pages | No CMS | Separate public website |
| Non-technical content editing for public pages | No CMS | WordPress/headless CMS alongside Gibbon |
| Public news/announcements feed | Gibbon's Messenger is internal-only | Public website CMS; or module to expose data publicly |
| Mobile-first simplified dashboards per role | Gibbon's default UI is full-featured admin-oriented | Custom Gibbon module + custom theme |
| REST API for future mobile app | No native API | Would require custom module to expose JSON endpoints |
| Token-based authentication (JWT, OAuth server) | Not native | Future work; out of MVP scope |
| WhatsApp/SMS automation | Not native | Out of MVP scope; future integration point |
| AI features | Not native | Out of MVP scope |

---

## Architecture Recommendation

**Build a custom Gibbon theme (`LittleGems`) for brand identity and a custom Gibbon module (`LittleGems Portal`) for simplified role-specific dashboards — both outside Gibbon core, version-controlled separately, and surviving upstream upgrades.** Build an independent public website (Next.js static site with a headless CMS, or WordPress) for the public-facing Little Gems presence, linking to the Gibbon portal for authenticated access. Deploy the entire stack as Docker Compose: Nginx + PHP-Apache (Gibbon) + MySQL 8.0, with the custom theme and module mounted as volumes.

---

## Risk Summary Table

| # | Risk | Severity | Probability | Mitigation |
|---|---|---|---|---|
| 1 | No REST API — headless SPA pattern not viable | High | Certain | Build within Gibbon's PHP rendering pipeline |
| 2 | No native CMS for public website | High | Certain | Build separate public website; plan content workflow |
| 3 | Theme template overrides may break on Gibbon upgrades | Medium | Likely (2×/year) | Document all overrides; upgrade review checklist |
| 4 | No official production Docker image | Medium | Certain | Build custom Docker Compose stack |
| 5 | Timetable setup complexity | Medium | Likely | Admin onboarding phase; detailed setup documentation |
| 6 | Homework UX insufficient for parent-friendly view | Medium | Likely | Custom dashboard or adopt community Homework Calendar module |
| 7 | v31 release during development | Low | Likely | Build upgrade-safe from day one; test custom theme after each release |
| 8 | GPL copyleft obligations if portal becomes product | Low | Unlikely (private use) | Legal review if distribution plans emerge |
| 9 | Nigeria connectivity — performance on slow connections | Medium | Possible | Prioritise image optimisation, CDN, PWA patterns in theme |
| 10 | Staff onboarding / training on Gibbon complexity | Medium | Likely | Provide administrator training + documentation as part of delivery |

---

## Questions to Answer Before Development Starts

1. **Public website content management:** Who will manage website content at Little Gems (technical or non-technical person)? This determines which CMS solution to choose.

2. **Timetable source data:** Does Little Gems have an existing timetable in digital form (Excel/spreadsheet)? If so, in what format? This affects Milestone 2 scope.

3. **Number of students, staff, families:** Rough user counts needed for server sizing decisions.

4. **Hosting environment:** Will the school host on a VPS (and if so, which provider/region), or is a managed cloud provider preferred? Nigeria connectivity and latency considerations apply.

5. **Domain/subdomain strategy:** Will the portal and public website share the same domain (e.g. littlegems.edu.ng for the public site, portal.littlegems.edu.ng for Gibbon)?

6. **Existing data:** Does the school have student/family data in any existing system? If so, Gibbon's CSV import can be used — what format is the data in?

7. **Language:** Will Gibbon be used in English only? Gibbon supports 29 languages — this affects initial setup.

8. **Google/Microsoft integration:** Does Little Gems use Google Workspace or Microsoft 365? If so, OAuth login integration is valuable.

9. **School calendar/events ownership:** Should the public website calendar be maintained separately from (or in sync with) the Gibbon events calendar?

10. **Module licensing:** The starter module allows replacing the GPL licence for custom modules. If Little Gems intends to keep the portal exclusively for their school, any licence (or no licence) is fine. If they plan to offer it to other schools in the future, this needs legal consideration early.

---

*Report generated: 2026-08-26 by Hermes Technical Discovery Subagent*  
*Next step: Milestone 1 — Repository setup, Docker Compose configuration, Gibbon installation, initial configuration*
