# index.html Code Architecture
## Internal Design Reference

---

## 1. File Structure (Single HTML File)

```
index.html
├── <head>
│   ├── Meta tags, fonts, CDN scripts (Supabase, Chart.js)
│   └── <style> — all CSS (~200 lines)
│
├── <body>
│   ├── #boot          — Loading spinner (shown until auth check completes)
│   ├── #auth          — Sign in / Create account screens
│   ├── #onboard       — First-time user onboarding (7 sections)
│   ├── #paywall       — Trial expired / subscription screen
│   ├── #app           — Main app (nav + 5 tab screens)
│   │   ├── <nav>      — Bottom navigation (Today/Food/Progress/Plan/More)
│   │   ├── #sc-today  — Today tab
│   │   ├── #sc-food   — Food diary tab
│   │   ├── #sc-prog   — Progress tab
│   │   ├── #sc-plan   — Plan tab
│   │   └── #sc-more   — Settings & More tab
│   ├── #closeday-modal — Close My Day popup
│   └── #sleep-notif-banner — Sleep reminder banner
│
└── <script> — all JavaScript (~1,800 lines)
    ├── Constants & config
    ├── Auth functions
    ├── Data loading
    ├── Render functions
    ├── Feature functions
    └── Utility functions
```

---

## 2. JavaScript Architecture

### Global State Variables
```javascript
var SBU, SBK     // Supabase URL + anon key (hardcoded)
var db           // Supabase client
var CU           // Current auth user (null if logged out)
var PRO          // User profile object (from profiles table)
var DAT          // In-memory data store:
                 //   DAT.weights[], DAT.steps[], DAT.habits{},
                 //   DAT.water{}, DAT.food{}

// Feature state
var HABITS       // Dynamic array built from PRO data
var pendingMeals // Meals added but not yet analysed
var pendingFood  // Last AI food analysis response
var lastFoodResultHTML  // Persists analysis across tab switches
var todayAnalysisCount  // AI calls used today (from localStorage)
var wChart, sChart      // Chart.js instances
```

### Boot Sequence
```
DOMContentLoaded
    → checkSession()
        → getSession() from Supabase
            [no session] → hide boot, show auth
            [session]    → fetchProfile()
                             → loadUserData()
                                → showApp()
                                    → refreshHabits()
                                    → renderToday()
                                    → renderFoodLog()
                                    → startNightWatcher()
```

### Data Flow
```
Supabase DB
    ↓ loadUserData() — fetches 90 days of all tables in parallel
DAT object (in-memory)
    ↓ render functions read DAT
DOM (what user sees)
    ↑ user interactions call save functions
Supabase DB (upsert)
    ↑ DAT also updated in-memory (no re-fetch needed)
```

---

## 3. Tab System

```javascript
function goTab(btn, name) {
  // 1. Hide all .sc divs, remove .on from nav buttons
  // 2. Show #sc-{name}, add .on to clicked button
  // 3. Call render function for that tab
}

// Tab render functions:
// today → renderToday()
// food  → renderFoodLog() + checkAnalyseReady() + restore lastFoodResultHTML
// prog  → renderProgress()
// plan  → renderAIPlan() if PRO.ai_plan exists
// more  → initFeedbackChips()
```

---

## 4. AI Integration

### All AI calls go through the same proxy:
```javascript
const res = await fetch("/api/chat", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({
    model: "claude-sonnet-4-20250514",
    max_tokens: 1000,
    messages: [{ role: "user", content: prompt }]
  })
});
const data = await res.json();
const parsed = JSON.parse(data.content[0].text
  .replace(/```json|```/g, "").trim());
```

### AI Features:
| Function | Trigger | Quota |
|----------|---------|-------|
| `analyseFood()` | "Analyse My Day" button | 2/day |
| `genPlan()` | Onboarding / Regenerate | Not counted |
| `runCloseDayAI()` | Close My Day → Get AI Summary | 1/day |

### Quota tracking:
```javascript
// Stored in localStorage, keyed by date
localStorage.getItem("analysis_count_2026-03-17")  // "2"
// Resets automatically next day (different key)
// Max: 2 for food, 1 for close day = 3 total
```

---

## 5. Health Context Injection

```javascript
function getHealthContext() {
  // Reads PRO.health_* values
  // Returns plain-English string e.g.:
  // "HbA1c 6.2% (pre-diabetic), Fasting sugar 108 mg/dL (pre-diabetic)"
  // Injected into ALL AI prompts automatically
}
```

---

## 6. Onboarding Flow

```
showOnboard()
    → User fills 8 sections:
        1. Preferred name
        2. Goals (chips)
        3. Body details (age, height, weight, goal weight)
        4. Equipment (chips)
        5. Exercise preferences (chips)
        6. Dietary style (chips)
        7. Health conditions (chips)
        8. Sleep (hours, bedtime, quality, score 0-100)
        9. Challenges (checkboxes: Cravings/Social media/No time/No discipline/Others)
    → submitOnboard()
        → Validates inputs
        → Calculates calorie target (Mifflin-St Jeor if not entered)
        → db.from("profiles").upsert(p)
        → genPlan(true)  ← AI generates personalised plan
            → finishOnboard()
                → showApp()
```

---

## 7. Close Day Flow

```
showCloseDay()
    → Reads DAT for today (food, steps, habits, water)
    → Builds compact 4-line summary
    → Populates "what worked" + "tomorrow challenge" chips
    → Shows food summary (from pendingFood or saved DAT.food assess)
    → Restores saved AI analysis from localStorage if already done
    → Shows modal

User interaction:
    → Selects chips
    → (Optional) runCloseDayAI()
        → Builds comprehensive prompt with all day data
        → Calls /api/chat
        → Saves result to localStorage (closeday_ai_YYYY-MM-DD, 7 days)
    → confirmCloseDay()
        → Saves to daily_logs table
        → Updates profiles.day_closed_date
        → Hides Close My Day button, shows "Day closed" message
```

---

## 8. CSS Design System

```css
/* Core variables */
--g:   #2D6A4F   /* primary green */
--gl:  #D8F3DC   /* light green */
--bg:  #F8FAF7   /* background */
--bo:  #DDE8DC   /* border */
--mu:  #6B7F6E   /* muted text */
--co:  #E76F51   /* warning/over */
--tx:  #1A2E1E   /* body text */
--ra:  12px      /* border radius */

/* Component classes */
.card    — white rounded card with border
.btn     — full-width green button
.btn-s   — small button
.btn-o   — outlined button
.mc      — metric card (stat display)
.h-row2  — habit row with checkbox
.dot     — week dot (today/done/missed)
.spin    — CSS spinner animation
.sc      — tab screen (display:none by default, .on = visible)
```

---

## 9. Key Patterns & Conventions

### Data save pattern (always upsert, surface errors):
```javascript
try {
  var res = await db.from("table").upsert(
    { user_id: CU.id, date: today(), value: v },
    { onConflict: "user_id,date" }
  );
  if (res.error) throw res.error;
  // Update in-memory DAT
  DAT.table[today()] = v;
  renderToday();
} catch(e) {
  alert("Save failed: " + (e.message || JSON.stringify(e)));
}
```

### Today's date helper:
```javascript
function today() {
  return new Date().toISOString().slice(0, 10); // "2026-03-17"
}
```

### Dynamic habits (personalised per user):
```javascript
function buildHabits() {
  // Reads PRO.exercise_pref, PRO.equipment, PRO.user_goals
  // Returns array of habit objects
  // Called once on login via refreshHabits()
}
```

### Avoiding common bugs:
- Use `str.replace()` result — JS doesn't modify strings in-place
- Always null-check DOM elements: `var el = document.getElementById("x"); if (el) el.value = ...`
- Use `update().eq("id", CU.id)` not `upsert()` for profiles (avoids RLS insert conflicts)
- `onchange` on range inputs doesn't fire reliably on mobile — use explicit Save buttons
