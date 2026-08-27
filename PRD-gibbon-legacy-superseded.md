# SUPERSEDED — Little Gems School Management Platform
## Historic Gibbon Direction (retained for decision history only)

> **Status:** Superseded on 2026-08-27 by [`PRD.md`](PRD.md), the authoritative **Native Next.js + Supabase MVP PRD**. Do not implement this Gibbon/PHP/WordPress direction. This file is preserved unchanged below as historic context.

---

# Little Gems School Management Platform
## MVP Product Requirements & Functional Specification

**Project:** Little Gems School Management Platform
**Client:** Little Gems School, Nigeria
**School Owner / Stakeholder:** Adrian Anyata
**Working Product Name:** Little Gems School Portal
**Foundation:** Gibbon School Platform
**Document Status:** Development Starting Brief / MVP PRD
**Primary Audience:** Hermes, Codex and development agents

---

## 1. Product Vision

Build a simple, modern and mobile-first digital platform for Little Gems School that brings the school's public website and day-to-day school management into one coherent experience.

The platform will use Gibbon as the underlying school-management foundation rather than rebuilding established school-management functionality from scratch.

The Little Gems implementation must feel like a purpose-built Little Gems product — not a generic Gibbon installation.

Users should not be confronted with every feature, menu or administrative option available within Gibbon. The application should expose a deliberately selected subset of functionality appropriate to each type of user.

### Core Principle
> Gibbon provides the school-management chassis. Little Gems provides the product experience.

The initial product should be:
- simple
- highly readable
- mobile-first
- responsive
- fast on modest internet connections
- easy for non-technical users
- role-based
- secure
- maintainable
- upgradeable without unnecessarily modifying Gibbon core
- capable of being extended with communications and AI services later

Architecture should avoid decisions that prevent the system from eventually becoming a reusable platform for additional schools.

---

## 2. MVP Users

Version 1 supports four primary authenticated user roles.

### Administrator
Broadest access. MVP capabilities:
- manage students, parents/guardians, teachers, classes, academic years/terms
- manage timetable information
- record or review attendance
- publish announcements
- manage school calendar/events
- access assessment/results information
- manage basic school content
- manage user accounts and permissions

Administrative experience may expose more of Gibbon than other interfaces, but unnecessary functionality should still be hidden.

### Teacher
Simple work dashboard — only relevant responsibilities. MVP capabilities:
- view assigned classes and students
- take attendance
- view timetable
- create/view assignments or homework
- enter/update permitted assessment information
- view announcements and school calendar
- access relevant student information

Teachers must not have access to unrelated administrative functions.

### Parent / Guardian
Particularly simple and mobile-friendly. A parent should be able to:
- see their child/children
- view attendance, timetable (where appropriate), assignments/homework
- see available academic results/reports
- read school announcements and upcoming events
- access relevant documents
- view basic school/contact information
- switch between multiple children easily

Parents must only see information relating to children for whom they are authorised guardians.

### Student
Simplest dashboard. Students should be able to:
- view their timetable
- view assignments/homework
- see relevant results
- read announcements
- view school events/calendar
- access permitted learning or school documents

---

## 3. Public Little Gems Website

A public-facing website independent of authentication.

Initial public sections:
- Home
- About Little Gems
- Admissions
- Academics
- News / Announcements
- School Calendar / Events
- Contact
- School Login

Content must be manageable without developers editing source code for routine updates.

The public website and authenticated portal must share a consistent Little Gems visual identity.

The website must not visually resemble an unmodified Gibbon installation.

---

## 4. User Experience Requirements

Ease of use is a primary functional requirement, not merely a design preference.

### Mobile First
Primary interface must work properly on smartphones. Must also adapt to tablets, laptops, and desktops. Must remain usable on small displays and modest mobile connections.

### Readability
**Use:**
- large default body text
- clear headings
- high visual contrast
- large buttons
- generous spacing
- obvious navigation
- large touch targets
- plain English

**Avoid:**
- dense administrative screens
- excessive nested menus
- unexplained technical terminology
- displaying functions simply because Gibbon makes them available

### Navigation
Important information reachable within approximately 2–3 interactions from the dashboard.

Each role has its own dashboard.

Example — Parent Dashboard flow:
`Child → Attendance → Homework → Results → Announcements → Calendar`

---

## 5. MVP Functional Modules

The following Gibbon capabilities should be configured rather than independently recreated wherever practical.

### Student Information
- student identity/profile, class/year group, enrolment status
- parent/guardian relationships
- appropriate contact information

### Staff
- teacher profiles, class relationships, subject/class assignments
- appropriate contact information, system roles

### Classes and Timetable
- class structure, teacher assignments, student assignments
- timetable viewing

### Attendance
- teachers/admins record attendance
- parents see permitted attendance for their children
- admins review attendance across school

### Assignments / Homework
- teachers publish assignments
- students and parents view relevant assignments

### Assessment / Results
- authorised staff enter/manage academic results via Gibbon
- parents and students only see released/permitted results

### Announcements
- admins publish school-wide or targeted announcements
- appear prominently on relevant dashboards

### Calendar
- term dates, holidays, examinations, parent events, school activities, important deadlines

### Documents
- controlled access to policies, forms, school notices, reports, learning materials

---

## 6. Authentication, Roles and Security

Authentication relies initially on Gibbon's supported authentication and permission mechanisms.

**Mandatory security rules:**
- Role-based access enforced server-side (never rely solely on hidden UI components)
- Students must not access other students' private records
- Parents must not access unrelated children's records
- Teachers receive only appropriate staff permissions
- Administrative functionality restricted
- Passwords never stored in plaintext
- All production traffic must use HTTPS
- Secrets/API credentials must not be committed to source control
- Appropriate backups must be established

Children's information requires privacy and data protection as core architectural concerns.

---

## 7. Proposed Architecture

Development team must investigate current supported Gibbon architecture before committing to final implementation.

**Conceptual architecture:**
```
Public Internet
      ↓
Little Gems Web Experience
  - Public Website
  - Parent Portal
  - Student Portal
  - Teacher Portal
  - Admin Experience
      ↓
Application / Integration Layer
      ↓
Gibbon
  - users, roles, students, families, classes
  - timetable, attendance, assessments, school records
      ↓
Database
```

**Implementation options to evaluate:**
1. Supported Gibbon theming/configuration
2. Gibbon modules/extensions
3. Separate frontend using supported Gibbon interfaces
4. Hybrid of these approaches

### Critical Engineering Constraint
> Avoid modifying Gibbon core unless absolutely necessary.

Customisation should live in configuration, themes, modules, extensions or an independent integration layer — so future Gibbon security and version upgrades remain practical.

---

## 8. Deployment

The system should be containerised where practical.

A reproducible deployment should contain:
- Gibbon/application service
- database
- reverse proxy
- Little Gems frontend (if separate)
- supporting services

Production configuration must be separated from source code.

The project repository must contain sufficient documentation to recreate the environment.

A basic backup and restore procedure must be documented and tested before production launch.

---

## 9. Branding

Full branding for Little Gems School including:
- Little Gems name and school logo
- School colours, typography, imagery
- Favicon/application icon
- Appropriate Nigerian school contact information

No prominent Gibbon branding should appear in the normal Little Gems user experience where white-labelling is technically and legally permitted.

Gibbon attribution/licensing requirements must be investigated and respected.

---

## 10. Out of Scope for MVP

Unless required to deliver the core school workflow, defer the following to post-MVP:
- AI assistants
- Hermes/Buzz agent integration
- Nostr messaging
- WhatsApp/SMS automation
- Sophisticated accounting or online payments
- Payroll, transport tracking, biometric attendance
- Native Android/iOS applications
- Advanced analytics
- Extensive e-learning functionality
- Custom functionality already adequately provided by Gibbon

Architectural decisions should nevertheless avoid making these unnecessarily difficult to add later.

---

## 11. Future Agent / Communications Layer

Reserve a clean integration boundary for future automation including:

- **Hermes** — Administrative and development automation
- **Buzz** — School communications and agent collaboration
- **Nostr / Private Relay** — Event/messaging infrastructure
- **AI Services** — draft announcements, summarise attendance, answer admin questions, help teachers, generate reports, assist parents, automate repetitive work

**Rule:** AI must not initially become a dependency for basic school operation. The school must continue functioning if external AI services are unavailable.

---

## 12. MVP Acceptance Criteria

The MVP is functionally complete when:
- [ ] Little Gems has a branded public website
- [ ] Site works on mobile and desktop
- [ ] Users can authenticate securely
- [ ] Administrator, Teacher, Parent and Student roles exist
- [ ] Each role receives an appropriately simplified interface
- [ ] Administrators can manage basic student, family, teacher and class information
- [ ] Teachers can access assigned students/classes and record attendance
- [ ] Parents can view information for their authorised children
- [ ] Students can access their permitted school information
- [ ] Announcements are operational
- [ ] School calendar/events are operational
- [ ] Basic homework/assignment functionality is operational
- [ ] Basic assessment/results viewing is operational
- [ ] Gibbon core has not been unnecessarily forked or modified
- [ ] Production deployment is reproducible
- [ ] Backups configured and restore procedure documented
- [ ] Core access-control tests pass
- [ ] Interface remains usable on a typical smartphone

---

## 13. Development Agent — First Assignment (Discovery Spike)

Before implementing major custom functionality, perform a Gibbon technical discovery spike.

Produce a short technical report covering:
1. Current stable Gibbon version
2. Installation requirements
3. Docker/container deployment options
4. Database requirements
5. Theme/branding capabilities
6. Module/plugin architecture
7. Available APIs or integration interfaces
8. Authentication architecture
9. Role/permission model
10. Student/parent/teacher data model
11. Attendance capabilities
12. Timetable capabilities
13. Assignment/homework capabilities
14. Assessment/reporting capabilities
15. Public website/content capabilities
16. Supported methods for creating a custom frontend
17. Upgrade implications of each customisation approach
18. Licensing/white-label requirements
19. Recommended Little Gems architecture
20. Major risks or functionality gaps

Do not begin a large-scale rewrite of Gibbon.

After discovery, propose the smallest architecture capable of delivering this PRD while retaining an upgrade path.

---

## 14. Delivery Sequence

### Milestone 0 — Discovery
Install and inspect Gibbon. Map this PRD against native functionality. Produce architecture recommendation.

### Milestone 1 — Foundation
Create repository, development environment, containerisation, database, configuration management, backups and baseline Gibbon installation.

### Milestone 2 — Little Gems Configuration
Configure school structure, academic year, roles, permissions and representative test users/data.

### Milestone 3 — UX & Branding
Implement Little Gems branding and simplified role-specific navigation/dashboard experience.

### Milestone 4 — Public Website
Implement the public Little Gems website and connect appropriate school content.

### Milestone 5 — Core Workflows
Complete and test attendance, timetable, homework, announcements, calendar and assessment/results workflows.

### Milestone 6 — Pilot
Populate realistic sample data and test end-to-end workflows with school stakeholders.

### Milestone 7 — Production
Deploy production environment, configure domain/HTTPS, backups, monitoring and administrator documentation.

---

## 15. Guiding Product Rule

Whenever there is a choice between exposing more functionality and making the application easier to understand:

> **Prefer simplicity.**

Gibbon should provide the underlying capability without dictating the Little Gems user experience.

The objective of Version 1 is not to create the world's most comprehensive school-management platform.

**The objective is to create a small, dependable and extremely easy-to-use digital school system that Little Gems can actually adopt.**

Once the school is successfully operating on that foundation, communications, payments, analytics, Buzz, Hermes and AI functionality can be introduced incrementally.
