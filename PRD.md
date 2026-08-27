# Little Gems School Platform
## Native Next.js + Supabase — MVP Product Requirements Document

**Project:** Little Gems School Platform  
**Client:** Little Gems School, Nigeria  
**Product:** Little Gems School Management System & Website  
**Architecture:** Native Next.js + Supabase  
**Document Status:** MVP Development Brief  
**Primary Audience:** MEPA / Hermes / Codex / Development Agents

---

## 1. Product Vision

Build a modern, fast, mobile-first digital school platform specifically for **Little Gems School**.

The platform will combine:

1. a public school website;
2. a secure school management system;
3. role-specific portals for administrators, teachers, parents and students;
4. a future integration layer for communications, payments, automation and AI.

Unlike the earlier Gibbon proposal, Little Gems will be a **native application**.

There will be no Gibbon, WordPress or PHP dependency.

### Core technology

- **Next.js**
- **TypeScript**
- **React**
- **Supabase**
- **PostgreSQL**
- **Supabase Auth**
- **Supabase Storage**
- **Tailwind CSS**
- modern component library where appropriate

The application should be capable of deployment to platforms such as Vercel, with Supabase providing managed backend infrastructure.

### Core Product Principle

> **Little Gems should contain only the functionality the school actually needs.**

Do not recreate every feature found in large commercial school-management systems.

The MVP should be deliberately small, clear and dependable.

---

# 2. Product Architecture

The preferred architecture is:

**Users**

↓  

**Next.js Application**

├── Public Website  
├── Admin Portal  
├── Teacher Portal  
├── Parent Portal  
└── Student Portal  

↓

**Application / Service Layer**

↓

**Supabase**

├── PostgreSQL Database  
├── Authentication  
├── Row Level Security  
├── Storage  
├── Realtime where appropriate  
└── Edge Functions where appropriate  

↓

**External Integrations — Later**

├── Email  
├── WhatsApp / SMS  
├── Payments  
├── Buzz  
├── Hermes / MEPA  
└── AI services

The public website and authenticated application should preferably exist within the same Next.js project unless technical discovery identifies a compelling reason to separate them.

---

# 3. Primary User Roles

Version 1 will support four primary authenticated roles.

## Administrator

Administrators operate the school.

Core capabilities:

- manage students;
- manage teachers;
- manage parents/guardians;
- manage classes;
- manage subjects;
- manage academic years and terms;
- manage enrolments;
- manage timetables;
- review attendance;
- publish announcements;
- manage school events;
- manage assessments/results;
- manage documents;
- manage public website content;
- manage user accounts.

---

## Teacher

Teachers should receive a focused dashboard.

Teachers can:

- view assigned classes;
- view assigned subjects;
- view timetable;
- view students in their classes;
- record attendance;
- create homework/assignments;
- enter permitted assessment results;
- view announcements;
- view school events;
- access permitted student information.

Teachers must not receive unnecessary administrative functionality.

---

## Parent / Guardian

Parents receive an extremely simple mobile-first portal.

Parents can:

- view their child/children;
- switch between children;
- view attendance;
- view timetable;
- view homework;
- view released results;
- view school announcements;
- view calendar/events;
- access school documents.

Parents must only be able to access children with whom they have an authorised guardian relationship.

---

## Student

Students receive the simplest portal.

Students can:

- view timetable;
- view homework;
- view attendance where permitted;
- view released results;
- read announcements;
- view school calendar/events;
- access permitted documents.

---

# 4. Public Website

The Next.js application will also provide the Little Gems public website.

Initial sections:

- Home
- About
- Academics
- Admissions
- News
- Events
- Contact
- School Login

The public site must be:

- responsive;
- SEO friendly;
- fast;
- accessible;
- visually consistent with the portal;
- manageable by authorised school staff.

Next.js server rendering/static generation should be used appropriately so public pages can be efficiently delivered through CDN infrastructure.

---

# 5. Simple Built-In CMS

The MVP should include a deliberately small content-management capability.

Administrators should be able to manage:

### Pages

- title;
- slug;
- page content;
- featured image;
- published/draft status;
- SEO title;
- SEO description.

### News

- title;
- body;
- image;
- publication date;
- author;
- status.

### Events

- title;
- description;
- date;
- time;
- location;
- image where required.

The objective is **not to build WordPress**.

Only functionality required to operate the Little Gems website should be implemented.

---

# 6. Core School Data Model

The development team should create a clean relational PostgreSQL schema.

Minimum entities should include:

- users
- profiles
- roles
- students
- teachers
- guardians
- student_guardians
- academic_years
- terms
- classes
- subjects
- class_enrolments
- teacher_assignments
- timetable_entries
- attendance_records
- assignments
- assessments
- assessment_results
- announcements
- events
- documents
- pages
- news_posts

Foreign-key relationships and database constraints should be used wherever appropriate.

Avoid storing relational information in arbitrary JSON fields unless there is a clear technical reason.

---

# 7. Authentication & Authorisation

Use **Supabase Auth**.

Initial authentication should support:

- email/password;
- password reset;
- session management.

Additional authentication mechanisms can be introduced later.

Authentication and authorisation are separate concerns.

A logged-in user must only access information allowed by their role and relationships.

### Supabase Row Level Security

RLS must be enabled for sensitive tables.

Examples:

**Parent**

Can retrieve records relating only to authorised children.

**Student**

Can retrieve only their own permitted information.

**Teacher**

Can retrieve information relating to authorised classes/students.

**Administrator**

Receives broader school-level access.

Security must not rely solely on frontend route protection.

Database policies must enforce appropriate access.

---

# 8. Dashboard Architecture

After authentication, users should automatically arrive at the dashboard appropriate to their role.

Example routes:

`/admin`

`/teacher`

`/parent`

`/student`

The navigation available within each portal should differ according to role.

Do not create one enormous dashboard and hide random buttons.

Build role-specific experiences.

---

# 9. UX Requirements

This is a critical requirement.

The application will be used by people with different levels of technical experience and potentially on inexpensive mobile devices.

### Design principles

Use:

- large readable typography;
- large buttons;
- large touch targets;
- simple navigation;
- clear icons accompanied by text;
- generous spacing;
- strong visual hierarchy;
- plain language.

Avoid:

- dense dashboards;
- tiny text;
- unnecessary settings;
- deeply nested navigation;
- developer terminology;
- excessive tables on mobile.

Most common Parent and Student tasks should be achievable within approximately **2–3 interactions from the dashboard**.

---

# 10. Mobile & Connectivity

The system must be designed mobile-first.

Priority devices:

1. Android smartphone
2. iPhone
3. Tablet
4. Laptop/Desktop

The application should remain usable under imperfect mobile-network conditions.

Optimise:

- JavaScript bundles;
- images;
- fonts;
- database requests;
- unnecessary client-side rendering.

Use server-side rendering, server components, caching and static generation appropriately.

Do not turn the entire application into a client-side SPA unnecessarily.

---

# 11. Attendance

Teachers should be able to:

1. select class;
2. select date/session;
3. see student list;
4. mark attendance;
5. submit.

Minimum statuses:

- Present
- Absent
- Late
- Excused

Administrators should be able to review attendance.

Parents should see attendance for their children.

Students may see their own attendance where enabled.

---

# 12. Homework / Assignments

Teachers can create assignments containing:

- title;
- description;
- class;
- subject;
- issue date;
- due date;
- optional attachment.

Students see relevant assignments.

Parents can see assignments belonging to their children.

Full LMS functionality is outside MVP scope.

---

# 13. Assessments & Results

Teachers can create or enter permitted assessment results.

Minimum structure:

**Assessment**

- academic year;
- term;
- class;
- subject;
- assessment name;
- maximum score;
- date.

**Result**

- student;
- assessment;
- score;
- optional comment;
- release status.

Parents and students must only see results that have been released.

---

# 14. Announcements

Administrators can publish announcements.

Announcements may target:

- entire school;
- teachers;
- parents;
- students;
- specific classes.

The relevant announcements should appear prominently on user dashboards.

The data model should permit future notification delivery through email, WhatsApp, SMS, push notifications or Buzz without redesigning the announcement system.

---

# 15. Calendar & Events

Administrators can create events including:

- term dates;
- holidays;
- examinations;
- school activities;
- parent meetings;
- deadlines.

Users see events relevant to their role/class.

Public events may also appear on the public website.

---

# 16. Documents & Storage

Use **Supabase Storage**.

Documents may include:

- school policies;
- forms;
- reports;
- homework attachments;
- learning resources;
- public website images.

Storage buckets and access policies must prevent unauthorised access to private documents.

Public and private assets should be separated appropriately.

---

# 17. Performance

Performance should be treated as an architectural requirement.

Target:

- fast first load;
- minimal unnecessary JavaScript;
- optimised images;
- CDN-delivered public assets;
- efficient database queries;
- pagination for large datasets;
- appropriate caching.

Avoid unnecessary dependencies.

Do not install large libraries for functionality that can reasonably be implemented with existing platform capabilities.

---

# 18. Security & Privacy

The application will contain children's information.

Security therefore has priority over development convenience.

Required controls include:

- HTTPS;
- Supabase RLS;
- secure authentication;
- role-based authorisation;
- protected storage;
- input validation;
- database constraints;
- environment-variable secret management;
- audit-friendly timestamps;
- appropriate logging;
- database backups.

No Supabase service-role key or other privileged credential may be exposed to browser code.

The team must consider Nigerian data-protection requirements and any other applicable privacy obligations before production use.

---

# 19. Deployment

Preferred initial deployment:

**Frontend/Application**

Vercel or equivalent modern Next.js-compatible hosting.

**Backend**

Supabase.

**Source Control**

GitHub.

Suggested environments:

- Development
- Staging
- Production

Production data must remain isolated from development/test environments.

Database migrations must be version controlled.

The project must be reproducibly deployable from the repository.

---

# 20. Development Standards

Use:

- TypeScript strict mode;
- current supported Next.js conventions;
- reusable components;
- server components where appropriate;
- schema validation;
- database migrations;
- linting;
- formatting;
- automated testing for critical workflows.

Prefer simple architecture over abstraction for abstraction's sake.

Agents must not introduce microservices into the MVP without a demonstrated requirement.

---

# 21. MVP Acceptance Criteria

The MVP is ready for pilot when:

- the public Little Gems website is operational;
- authorised staff can manage public website content;
- authentication works;
- Admin, Teacher, Parent and Student roles work;
- RLS policies have been tested;
- administrators can manage core school records;
- parent-child relationships work correctly;
- classes and enrolments work;
- teacher assignments work;
- timetable works;
- attendance works;
- homework works;
- basic assessments/results work;
- announcements work;
- calendar/events work;
- document storage works;
- role-specific dashboards work;
- mobile UX is usable;
- production deployment is reproducible;
- database backup/recovery procedures exist;
- critical security tests pass.

---

# 22. Explicitly Out of Scope — MVP

Do not implement unless subsequently authorised:

- payroll;
- HR management;
- advanced accounting;
- full LMS functionality;
- live classroom/video;
- transport tracking;
- biometric attendance;
- native Android application;
- native iOS application;
- complex analytics;
- AI assistants;
- Buzz integration;
- Nostr integration;
- WhatsApp automation;
- SMS automation;
- online fee payments.

These are potential later phases.

---

# 23. Future Architecture

The system should be designed so that future services can interact with Little Gems through a controlled application/API layer.

Potential integrations include:

### Communications

- Email
- WhatsApp
- SMS
- Push notifications
- Buzz

### Payments

- school fees;
- event payments;
- other school charges.

### AI / Agents

Hermes/MEPA or other agents could eventually:

- prepare announcements;
- summarise attendance;
- identify administrative tasks;
- prepare reports;
- assist teachers;
- answer authorised parent questions;
- generate school communications;
- analyse school operational data.

AI must remain an optional service.

Core school operation must not depend upon an external AI model being available.

---

# 24. SaaS-Readiness

Little Gems is the first implementation.

The MVP does **not** need to be a full multi-tenant SaaS product.

However, agents should avoid architectural decisions that unnecessarily prevent the application later supporting:

**School A**

**School B**

**School C**

through the same platform.

Where inexpensive to do so, school-owned entities should therefore be capable of association with a `school_id` or equivalent tenant boundary.

Do not build complex multi-tenancy prematurely.

Simply preserve the migration path.

---

# 25. Development Phases

## Phase 0 — Technical Foundation

Before building screens:

- establish repository;
- confirm supported Next.js version;
- establish Supabase project;
- establish local development;
- establish environment management;
- define database migration strategy;
- define authentication architecture;
- define RLS strategy;
- produce initial database schema.

**Deliverable:** working application shell connected securely to Supabase.

## Phase 1 — Identity & School Structure

Implement:

- authentication;
- profiles;
- roles;
- students;
- guardians;
- teachers;
- academic years;
- terms;
- classes;
- subjects;
- enrolments;
- teacher assignments.

## Phase 2 — Role Dashboards

Implement:

- Admin dashboard;
- Teacher dashboard;
- Parent dashboard;
- Student dashboard.

Use representative seed data to verify each role.

## Phase 3 — Core School Operations

Implement:

- timetable;
- attendance;
- assignments;
- assessments/results;
- announcements;
- events/calendar;
- documents.

## Phase 4 — Public Website

Implement:

- public pages;
- news;
- admissions content;
- events;
- contact;
- CMS administration;
- SEO;
- login entry point.

## Phase 5 — Hardening

Perform:

- RLS/security testing;
- cross-role access tests;
- mobile testing;
- performance testing;
- accessibility review;
- backup/restore testing;
- production configuration review.

## Phase 6 — Pilot

Deploy staging/pilot system with realistic school data.

Test with actual representatives of:

- administration;
- teachers;
- parents;
- students.

Fix usability problems before adding new functionality.

---

# 26. First Assignment for Hermes / Codex

Do **not** immediately build the complete application.

First perform a **technical architecture and schema spike**.

The agent should:

1. inspect this PRD;
2. identify ambiguous requirements;
3. confirm the current stable Next.js/Supabase implementation patterns;
4. propose the repository structure;
5. design the PostgreSQL schema;
6. design role and permission architecture;
7. design initial RLS policies;
8. define public/private Supabase Storage strategy;
9. define route architecture;
10. define CMS approach;
11. define migration strategy;
12. define seed-data strategy;
13. define testing strategy;
14. identify security/privacy risks;
15. identify likely MVP implementation risks.

Produce:

- architecture proposal;
- ER/data model;
- route map;
- RLS matrix;
- repository structure;
- implementation milestones;
- risk register.

**Stop after the technical design and request approval before beginning full implementation.**

---

# 27. Engineering Doctrine

The development team should repeatedly ask:

> **Does Little Gems actually need this?**

If not, do not build it.

Prefer:

**simple over clever;  
secure over convenient;  
fast over feature-heavy;  
mobile over desktop-first;  
standard platform capabilities over custom infrastructure;  
maintainable code over unnecessary abstraction.**

The objective of the MVP is not to reproduce Gibbon, PowerSchool or Moodle.

The objective is to provide Little Gems School with the **smallest modern school-management platform that successfully runs the school's essential digital operations**.

Once that foundation is proven in real school use, additional functionality can be introduced based on actual requirements rather than assumptions.