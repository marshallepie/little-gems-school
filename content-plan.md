# Little Gems Private School — Website Content Plan

**School:** Little Gems Private School (LGPS)
**Est.:** 1994 | **Motto:** "Winning From The Start" | **Tagline:** "Catch Them Young"
**Proprietress:** Mrs F. O. Femi-Pearse
**Stakeholder:** Adrian Anyata
**Platform Foundation:** Native Next.js + Supabase MVP

> 📄 Full product requirements: see `PRD.md` in this folder.
> Public website is **Section 4** of the authoritative Native Next.js + Supabase PRD. Content here maps to those pages.

---

## Assets Inventory

### Images Received (13 total)

| # | File | Description | Recommended Use | Status |
|---|------|-------------|-----------------|--------|
| 1 | img_40c3dde2388c.jpg | Young pupils on stage, graduation gowns (green/maroon), balloon arch | Hero slider / Events | ✅ Use |
| 2 | img_6ef5d6e55243.jpg | 4 older female students in formal green gowns, seated | Events / Gallery | ✅ Use |
| 3 | img_a25176bc5e83.jpg | School logo — purple crest, "LG", "Winning From The Start" | Navbar / Header / Favicon | ⭐ Essential |
| 4 | img_bdc838102c74.jpg | Vision & Mission wall plaque (photographed) | About / Mission page | ✅ Use (text also needed as copy) |
| 5 | img_831876227f05.jpg | School logo — duplicate of #3 | — | ℹ️ Duplicate |
| 6 | img_e6cce0a95f8d.jpg | Edulight Spelling Bout 2019–20 achievement board (1st Runner-Up) | Achievements / Awards | ✅ Use |
| 7 | img_fd7f2ae22eb5.jpg | School building exterior (yellow + purple fence) | About / Contact / Find Us | ✅ Use |
| 8 | img_2bf74daa5180.jpg | Graduation hall — wide shot, packed audience | Events Gallery | ✅ Use (crop left side) |
| 9 | img_a2d91fed2006.jpg | Boys in smart green waistcoats, bow ties, sunglasses | Events / Gallery | ✅ Use |
| 10 | img_15adac2a328f.jpg | Girls on stage in graduation gowns, performing | Hero slider / Events | ⭐ Highly Recommended |
| 11 | img_65ccaa814353.jpg | 4 girls in deep green formal gowns, seated (possible duplicate of #2) | Events / Gallery | ✅ Use (verify vs #2) |
| 12 | img_6d5bd248b5e1.jpg | ICT/Computer lab — students on laptops in purple uniform | Academics / Facilities | ⭐ Highly Recommended |
| 13 | img_a25a23ecf739.jpg | Genius Spelling Bout Season 1 — Lagos State Primary CHAMPION board (student with trophy) | Homepage achievements strip / Awards page | ⭐ Highly Recommended |

---

## Page Content

### 1. Homepage

#### Hero/Banner — Proprietress Quote
> **"For 32 years, God has helped us raise responsible, intelligent children who stand out anywhere in the world. At Little Gems, every child is a gem — loved, nurtured, and prepared to lead and win from the start."**
>
> — *Mrs F. O. Femi-Pearse, Proprietress*

**Suggested imagery for hero:** Image #1 or #10 (pupils performing on stage) or #8 (graduation hall)

---

### 2. About / Proprietress' Message

#### Section Heading
**From The Desk Of The Proprietress**

#### Full Message
Dear Esteemed Parents, Guardians, and Friends of Little Gems,

It is with great joy and gratitude that I welcome you to Little Gems Private School.

When we opened our doors on April 25, 1994, with the simple motto "Catch Them Young", our vision was clear: to lay a solid foundation for children that will enable them to compete favourably anywhere in the world. Today, 32 years later, that vision has grown into a legacy — and it is all to God's glory.

At LGPS, we believe that every child is a gem — unique, precious, and full of potentials. Our commitment is to polish that gem through quality education, strong moral values, creativity, and character.

Our vision, *"To become a world-class leading educational institution in Africa that promotes Wholistic development of every child"*, guides everything we do. From the classroom to the playground, from academics to arts, we are raising confident, disciplined, and globally competitive leaders.

Our standard on academics and character cannot be overemphasised. Our children are a testimony. One of our students relocated abroad and, having been placed directly in Grade 3, is now serving as a Mathematics Instructor. While still in JSS1 here in Nigeria, he was teaching SS1 students Mathematics they could not solve. This is the LGPS difference.

I thank you for the trust you have placed in us over the past three decades. To our new families, welcome to a home where your child will be loved, nurtured, and challenged to win — from the very start.

Together, let us continue to build the future, one gem at a time.

*With warm regards,*
**Mrs F. O. Femi-Pearse**
Proprietress, Little Gems Private School
Est. 1994

---

### 3. Vision & Mission

**Vision:**
To become a World Class Leading Educational Institution in Africa that promotes Wholistic Development of every Child.

**Mission:**
Creating an enabling environment for discovery and development of TALENTS and Laying A Solid Academic Foundation with the FEAR of GOD and Sound Character.

*(Source: Vision & Mission board — Image #4)*

---

### 4. Achievements / Awards

- **Genius Spelling Bout Season 1** — 🏆 **CHAMPION**, Lagos State Primary Category
  - Student holding large gold trophy featured prominently *(Image #13)*

- **Edulight Spelling Bout (ESB) 2019–2020** — 1st Runner-Up, Lagos State Primary School Category
  - Student spotlight: **Uzodinma Chisom** *(Image #6)*

---

## Public Site Page Structure (per authoritative PRD Section 4)

| Page | Content Status | Assets |
|------|---------------|--------|
| Home | ✅ Hero quote ready | Images #1, #10, #8 |
| About Little Gems | ✅ Proprietress message ready | Images #4, #7 |
| Admissions | ⏳ Content needed | — |
| Academics | ⏳ Content needed | Image #12 (ICT lab) |
| News / Announcements | ⏳ Dynamic via built-in Native Next.js + Supabase CMS | — |
| School Calendar / Events | ⏳ Dynamic via Native Next.js + Supabase events CMS | Images #1, #8, #9, #10 |
| Contact | ⏳ Address/phone needed | Image #7 (building exterior) |
| School Login | ⚙️ Supabase Auth entry point — no content needed | — |

---

## Notes & To-Dos

- [x] Receive and assess all 13 images ✅
- [x] PRD saved to PRD.md ✅
- [ ] Confirm whether Image #11 is a duplicate of Image #2
- [ ] Reproduce Vision & Mission text as web copy (not just image)
- [ ] Confirm school colours: Deep green, maroon/burgundy, purple, gold
- [ ] Obtain higher-res or vector version of logo if available
- [ ] Add content for: Admissions, Academics, Contact pages
- [ ] Confirm school address, phone number, email for Contact page
- [x] Native Next.js + Supabase technical architecture/schema spike completed — approval required before implementation
