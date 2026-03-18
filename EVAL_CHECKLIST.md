# Wellness App — Pre-Deploy Eval Checklist
## Run before every deploy. Fix any FAIL before deploying.

---

## LEVEL 1: Static Checks (run in terminal, 30 seconds)

```bash
cd ~/wellness-final

# 1. JS syntax clean
node --check index.html && echo "✅ JS syntax" || echo "❌ JS syntax BROKEN"

# 2. File sizes sane
wc -c index.html | awk '{if($1>100000 && $1<220000) print "✅ HTML size "$1; else print "❌ HTML size wrong "$1}'

# 3. Critical functions + features present
python3 -c "
html = open('index.html').read()
checks = [
  ('var OB_GOALS',             True,  'Onboarding goals array'),
  ('var OB_SLEEP_QUAL',        True,  'Onboarding sleep quality array'),
  ('var OB_EQUIP',             True,  'Onboarding equipment array'),
  ('signOut().then',           True,  'Sign out works on mobile (no confirm)'),
  ('closeday-modal',           True,  'Close Day modal HTML exists'),
  ('cd-food-analysis',         True,  'Close Day food section exists'),
  ('addMealToLog',             True,  'Add meal function'),
  ('fresh.data.map',           True,  'Food reload after analysis'),
  ('auto-save',                True,  'Analysis auto-saves to DB'),
  ('Analyse & Save',           True,  'Correct button label'),
  ('Save to Diary',            False, 'Save to Diary button REMOVED'),
  ('getHealthContext',         True,  'Health context for AI'),
  ('buildHabits',              True,  'Dynamic habits'),
  ('runCloseDayAI',            True,  'Close Day AI function'),
  ('food_analysis',            True,  'Close Day food analysis section'),
  ('habit_analysis',           True,  'Close Day habit analysis section'),
  ('water_analysis',           True,  'Close Day water analysis section'),
  ('activity_analysis',        True,  'Close Day activity analysis section'),
  ('renderTodayWater',         True,  'Water slider render'),
  ('ANTHROPIC_API_KEY',        False, 'API key NOT in index.html'),
  ('submitFeedback',           True,  'Feedback function'),
  ('calStatus',                True,  'Clean calorie for close day'),
  ('todayAnalysisCount',       True,  'Analysis quota tracking'),
  ('daily_usage',              True,  'Server-side quota table'),
  ('isPending',                True,  'Pending badge logic'),
]
ok = True
for term, should, label in checks:
  found = term in html
  status = '✅' if found == should else '❌'
  if found != should: ok = False
  print(f'{status} {label}')
print()
print('ALL CHECKS PASSED' if ok else '❌ SOME CHECKS FAILED — DO NOT DEPLOY')
"

# 4. API proxy works (run after deploy)
curl -s -X POST https://wellness-final.vercel.app/api/chat \
  -H "Content-Type: application/json" \
  -d '{"model":"claude-sonnet-4-20250514","max_tokens":5,"messages":[{"role":"user","content":"hi"}]}' \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('✅ API proxy working') if 'content' in d else print('❌ API proxy BROKEN:', d)"
```

---

## LEVEL 2: Manual Browser Checks (5 minutes, do after every deploy)

### Auth
- [ ] App loads with spinner (no sign-in flash)
- [ ] Sign in works
- [ ] **Sign out works on mobile (no confirm dialog)**
- [ ] New user sees onboarding

### Onboarding
- [ ] **Goals chips visible (7 options)**
- [ ] **Equipment chips visible (6 options)**
- [ ] Exercise chips visible (7 options)
- [ ] Diet chips visible (4 options)
- [ ] **Sleep quality chips visible (5 options)**
- [ ] Challenges checkboxes (4 + Others)
- [ ] Sleep score slider 0–100
- [ ] Bedtime dropdown (not system time picker)
- [ ] "Generate My Plan" button works → app opens

### Today Tab
- [ ] Greeting shows preferred name
- [ ] Steps input shows saved value on load
- [ ] Water slider shows saved value on load
- [ ] Habits list personalised to user's onboarding
- [ ] Calories shows correct total from food log
- [ ] Close My Day button visible (if day not closed)
- [ ] After Close My Day → button hidden, "Day closed ✓" shown

### Food Tab — NEW SIMPLIFIED FLOW
- [ ] Date shown at top
- [ ] **"+ Add Meal" saves immediately** (visible in Today's Log with "pending" badge)
- [ ] **Added meal survives page reload** (saved in DB)
- [ ] **"Analyse & Save My Day" button visible** after adding any meal
- [ ] **Analysis runs on ALL today's meals** (not just new ones)
- [ ] **kcal updates automatically in Today's Log** (no "Save to Diary" needed)
- [ ] **"✓ Saved to diary automatically"** confirmation appears
- [ ] **NO "Save to Diary" button** anywhere
- [ ] Today tab calories correct after analysis
- [ ] Analysis result persists when switching tabs and back
- [ ] Quota shows "1 of 2 remaining" after first analysis
- [ ] After 2 analyses: button shows "Limit reached (2/day)"

### Progress Tab
- [ ] Weight input saves
- [ ] Weight chart renders with today's entry
- [ ] Steps chart renders

### Plan Tab
- [ ] AI plan renders if onboarding done
- [ ] Regenerate Plan button works
- [ ] Edit My Plan textarea works

### More Tab
- [ ] Beta banner visible
- [ ] Health parameters save and reload on next visit
- [ ] Feedback chips + textarea work
- [ ] Redo onboarding resets and shows onboarding

### Close My Day
- [ ] Button opens modal (not blank)
- [ ] Modal shows compact summary (calories, steps, habits, water)
- [ ] What worked chips selectable (green)
- [ ] Tomorrow challenge chips selectable (orange)
- [ ] Next-day tip appears on challenge selection
- [ ] **"Get AI Summary" shows 7 sections**: Food / Habits / Water / Activity / Health Note / Goal Progress / Tomorrow
- [ ] AI result persists on modal reopen same day (localStorage)
- [ ] "Confirm & Close Day ✓" closes modal + hides button + shows "Day closed"

---

## LEVEL 3: Regression Tests

### Food logging regression (run when food code changes):
```
1. Add Breakfast → close app → reopen → Breakfast still there with "pending" badge ✅
2. Tap "Analyse & Save My Day" → breakdown shows → kcal replaces "pending" ✅
3. Today tab calories = grand_total from analysis ✅
4. Reload → kcal still correct ✅
5. Add Dinner later → tap Analyse again → ALL meals re-analysed → total updated ✅
6. No "Save to Diary" button anywhere ✅
7. Remove meal (✕) → deleted from DB immediately ✅
9. Quota is PER USER ACCOUNT not per device — works same on mobile + desktop ✅
8. No duplicate entries after multiple analyses ✅
```

### Onboarding regression:
```
1. New account → sees onboarding immediately
2. All sections render with correct options
3. Goals: 7 chips visible ✅
4. Equipment: 6 chips visible ✅
5. Sleep quality: 5 chips visible ✅
6. Challenges: 4 checkboxes + Others text box ✅
7. Submit → plan generated → app opens ✅
8. Reload → does NOT show onboarding again ✅
```

### Close Day regression:
```
1. Open modal → shows today's accurate data ✅
2. "Get AI Summary" → 7 sections render ✅
3. Close + reopen modal same day → AI result restored from localStorage ✅
4. Confirm → button hidden, "Day closed ✓" shown on Today tab ✅
5. Next day → button reappears ✅
```

---

## Food Flow Summary (post-simplification)

```
OLD (3 steps, confusing):
  Add Meal → Analyse → Save to Diary

NEW (2 steps, clear):
  + Add Meal    → saves to DB immediately (0 kcal, "pending" badge)
  Analyse & Save → analyses ALL today's meals → updates ALL kcal in DB automatically
```

---

## Known Regression Patterns

| Change Made | What Broke | Root Cause |
|-------------|-----------|------------|
| Added OB_GOALS | OB_SLEEP_QUAL missing | Both removed in same refactor |
| Added food staging | logFood saved duplicates | savedDesc + pendingDesc both sent to AI |
| Added food-pending-card | Analyse button hidden | Button was inside hidden div |
| Added modal food section | Close Day button did nothing | JS crashed on null cd-food-analysis |
| Changed calorie prompt | Close Day quoted wrong numbers | Stale foodAssess still in prompt |
| Added setInterval night watcher | DevTools opened every click | SW + interval conflict |
| Added sw.js cache | Old app served forever | skipWaiting() forces reload |
| Re-linked Vercel project | ANTHROPIC_API_KEY missing | Env vars don't transfer between projects |

---

## Quick Fix Commands

```bash
# Reset onboarding for a user
# Supabase SQL Editor:
# update profiles set onboarded = false where email = 'user@email.com';

# Clear duplicate food entries
# delete from food_log a using food_log b
# where a.ctid > b.ctid and a.user_id = b.user_id
# and a.date = b.date and a.meal = b.meal;

# Reset analysis quota — NOW IN SUPABASE (not localStorage)
# Run in Supabase SQL Editor:
# delete from daily_usage where user_id = 'your-uuid' and date = current_date;
# OR reset all users for testing:
# delete from daily_usage where date = current_date;
# OR use Supabase Table Editor → daily_usage → delete today's rows

# Clear stale close day AI (browser console)
# localStorage.removeItem('closeday_ai_' + new Date().toISOString().slice(0,10))

# Hard refresh (bypass cache)
# Chrome desktop: Cmd+Shift+R
# Mobile: Chrome Settings → Site settings → Clear & reset
```
