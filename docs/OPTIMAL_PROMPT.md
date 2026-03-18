# Optimal Prompt for Building This App from Scratch
## Use this to rebuild or extend the wellness PWA efficiently

---

## One-Shot Prompt (paste this into a new Claude conversation)

```
Build a personal wellness tracking Progressive Web App (PWA) with these exact specifications.

## Tech Stack (non-negotiable)
- Frontend: Single index.html file (~100-150KB) — vanilla JS/HTML/CSS, no framework, no build step
- Backend: Supabase (PostgreSQL + Auth + Row Level Security)
- Hosting: Vercel (static file + one serverless function)
- AI: Anthropic Claude Sonnet via /api/chat.js proxy (key stored in Vercel env, never in HTML)
- Charts: Chart.js via CDN

## Architecture Rules
1. Everything in one index.html — no separate CSS or JS files
2. One Vercel serverless function at api/chat.js — proxies Anthropic API
3. All DB writes use upsert with onConflict, all reads are parallel Promise.all
4. Row Level Security on every Supabase table
5. No optional chaining (?.) — use && fallbacks for browser compatibility
6. No template literals in HTML-building strings — use single-quote string concatenation
7. Surface all errors to user via alert() during development

## Supabase Credentials
- URL: [INSERT_SUPABASE_URL]
- Anon Key: [INSERT_ANON_KEY]
Store as: var SBU = "url"; var SBK = "key"; at top of script tag.

## Core Data Model
Tables: profiles (one per user), weights, steps, water, habits, food_log, 
        health_reports, daily_logs, promo_codes, feedback
All tables: user_id uuid references auth.users, date date, created_at timestamptz
Unique constraints: (user_id, date) for daily tables, (user_id, date, habit_id) for habits

## Features to Build

### Auth & Onboarding
- Boot screen (spinner, no flash of sign-in)
- Sign in / Create account (email + password)
- Onboarding flow on first login collecting:
  preferred name, goals, age/height/weight/goal weight,
  equipment, exercise preferences, diet style, health conditions,
  sleep hours/bedtime/quality/score (0-100, Ultrahuman scale), challenges
- Auto-calculate calorie target using Mifflin-St Jeor if not entered
- Generate AI wellness plan via /api/chat on completion

### 5 Tabs: Today / Food / Progress / Plan / More

**Today Tab**
- Greeting with preferred name, date
- 4 stats: current weight, BMI, kg lost, day streak
- Dynamic habits checklist (built from user's exercise_pref, equipment, user_goals)
- Tip of the day (cycling array)
- Calorie tracker (logged vs target, remaining)
- Week dots (7-day habit completion visual)
- Steps input (number box, Save button, shows saved value on load)
- Water slider (0-10 glasses, Save button, shows saved value on load)
- Close My Day button (dark green, bottom)

**Food Tab**
- Date shown at top
- Add meal form: meal type selector + textarea + "+ Add Meal" button
- Pending meals card (shows added meals with ✕ to remove)
- Today's Log (shows all saved meals + pending with "pending analysis" badge)
- Analyse button (visible always, shows "Re-analyse (N left)" after use)
- AI analysis result card (persists across tab switches via lastFoodResultHTML)
- Save to Diary button after analysis
- Past days summary
- Limit: 2 food analyses/day (shared 3/day total with Close Day AI)

**Progress Tab**
- Weight input (date + kg, Save button)
- Weight trend chart (Chart.js line, with goal line)
- Steps bar chart (last 14 days)
- Weekly report generator (AI summary button)
- Habit completion rates

**Plan Tab**
- AI-generated personalised plan (from genPlan())
- Regenerate Plan button
- Edit My Plan button (opens textarea for custom instructions)
- Plan shows: summary, weekly schedule, strength plan, nutrition, sleep tips, challenges advice

**More Tab**
- Beta banner (free during beta, subscription coming)
- Feedback form (chips + textarea + optional contact)
- Profile settings (name, weights, height, calorie target, birth year)
- Health parameters (sugar, cholesterol, BP, HbA1c, triglycerides, Hb, vitamins, uric acid, other notes)
  → These feed into ALL AI prompts via getHealthContext()
- Data section (export JSON, redo onboarding)

### Close My Day
- Floating button on Today tab + sleep banner trigger
- Modal with: compact day summary, what-worked chips, tomorrow-challenge chips
- Next-day tip (from NEXT_DAY_TIPS lookup by challenge type)
- "Get AI Summary for Today" button (1 AI call, cached in localStorage 7 days)
- AI returns: honest_take, goal_progress, tomorrow_strategy, motivation
- "Confirm & Close Day ✓" saves to daily_logs + profiles.day_closed_date
- Day closed state: hides Close Day button, shows "Day closed ✓"

### Trial & Paywall
- 30-day free trial tracked via profiles.signup_date
- After 30 days: show paywall with ₹149/month subscription option
- Promo code input: check promo_codes table, unlock if valid
- Pre-seeded codes: WELLNESS2025 (lifetime), FAMILY2025 (6 months), BETA (3 months)

### AI Features
All via /api/chat (POST to /api/chat, Claude returns JSON only):
1. genPlan() — wellness plan JSON on onboarding/regenerate
2. analyseFood() — food analysis JSON with per-meal breakdown + grand total
3. runCloseDayAI() — end-of-day summary JSON
4. Quota: localStorage analysis_count_YYYY-MM-DD, max 3/day, auto-resets

## Design System
Colors: --g #2D6A4F (green), --gl #D8F3DC (light green), --bg #F8FAF7, --co #E76F51 (warning)
Font: DM Sans (body), DM Serif Display (headings), both from Google Fonts
Cards: white bg, 12px radius, 1px #DDE8DC border
Buttons: full-width green with 12px radius
Mobile-first, max-width 520px centered

## Output Required
1. index.html — complete working single file
2. api/chat.js — CommonJS Vercel serverless function
3. manifest.json — PWA manifest
4. sw.js — service worker (network-first for HTML, cache-first for assets)
5. vercel.json — routing rules (/api/* → serverless, everything else → index.html)
6. migration.sql — all CREATE TABLE and ALTER TABLE statements (safe to re-run)

## Quality Requirements
- JavaScript syntax must pass `node --check`
- All event listeners via addEventListener, not onclick attributes with quotes-in-strings
- All saves surface errors to user
- Water/steps inputs show saved value on page load
- No duplicate food entries (logFood saves only pendingMeals, not all AI-returned meals)
```

---

## Tips for Efficient Implementation

1. **Start with the schema** — get migration.sql right first, deploy to Supabase
2. **Build auth + boot sequence** — get login working before any features
3. **Build one tab at a time** — Today → Food → Progress → Plan → More
4. **Test each AI prompt separately** using curl before wiring to UI
5. **Use deploy.py pattern** — embed index.html as base64, run python3 deploy.py to push
6. **Check syntax after every JS edit** — `node --check index.html` catches 90% of bugs
7. **Always upsert, never insert** for daily data — prevents duplicate entries

---

## Estimated Build Time

| Phase | Time |
|-------|------|
| Schema + auth + onboarding | 2-3 hours |
| Today + Food + Progress tabs | 3-4 hours |
| Plan + More + AI integration | 2-3 hours |
| Close Day + Trial/Paywall | 1-2 hours |
| Polish + bug fixes | 2-3 hours |
| **Total** | **~12-15 hours** |

With Claude doing the heavy lifting: **3-4 focused sessions of 2-3 hours each.**
