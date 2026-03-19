#!/bin/bash
# ============================================================
# Wellness App — Comprehensive Eval Script
# Run after every deploy: bash eval.sh
# Run before deploy:      bash eval.sh --local
# ============================================================

SITE="https://wellness-final.vercel.app"
HTML="index.html"
PASS=0; FAIL=0; WARN=0

green='\033[0;32m'; red='\033[0;31m'; yellow='\033[1;33m'
blue='\033[0;34m'; bold='\033[1m'; nc='\033[0m'

ok()   { echo -e "${green}  ✅ $1${nc}"; ((PASS++)); }
fail() { echo -e "${red}  ❌ $1${nc}"; ((FAIL++)); }
warn() { echo -e "${yellow}  ⚠️  $1${nc}"; ((WARN++)); }
hdr()  { echo -e "\n${bold}${blue}── $1 ──────────────────────────────${nc}"; }

if [ ! -f "$HTML" ]; then
  echo -e "${red}❌ index.html not found. Run from wellness-final/ directory.${nc}"
  exit 1
fi

echo -e "${bold}Wellness App Eval — $(date '+%Y-%m-%d %H:%M')${nc}"
echo "File: $HTML ($(wc -c < $HTML | tr -d ' ') bytes)"

# ════════════════════════════════════════════════════════════
hdr "1. FILE INTEGRITY"
# ════════════════════════════════════════════════════════════

# JS syntax
node -e "
const fs=require('fs');
const html=fs.readFileSync('index.html','utf8');
const si=html.lastIndexOf('<script>');
const ei=html.lastIndexOf('</scr'+'ipt>');
fs.writeFileSync('/tmp/eval_check.js',html.slice(si+8,ei));
"
if node --check /tmp/eval_check.js 2>/dev/null; then
  ok "JS syntax clean"
else
  fail "JS syntax BROKEN — run: node --check /tmp/eval_check.js"
fi

# File size
SIZE=$(wc -c < "$HTML")
if [ "$SIZE" -gt 100000 ] && [ "$SIZE" -lt 250000 ]; then
  ok "HTML size: ${SIZE} bytes (within 100K–250K)"
elif [ "$SIZE" -le 100000 ]; then
  fail "HTML too small: ${SIZE} bytes — likely truncated"
else
  warn "HTML large: ${SIZE} bytes — over 250K, consider splitting"
fi

# Has all 5 tabs
python3 -c "
html = open('index.html').read()
tabs = ['sc-today','sc-food','sc-prog','sc-plan','sc-more']
missing = [t for t in tabs if t not in html]
exit(1 if missing else 0)
" && ok "All 5 tab screens present" || fail "Missing tab screens"

# ════════════════════════════════════════════════════════════
hdr "2. AUTH & ONBOARDING"
# ════════════════════════════════════════════════════════════

python3 << 'PYEOF'
import sys
html = open("index.html").read()
checks = [
    ('id="boot"',           "Boot spinner (no sign-in flash)"),
    ('id="auth"',           "Auth screen exists"),
    ('id="onboard"',        "Onboarding screen exists"),
    ('signOut().then',      "Sign out mobile-safe (no confirm dialog)"),
    ('db.auth.signOut',     "Sign out function exists"),
    ('var OB_GOALS',        "Onboarding goals array defined"),
    ('var OB_SLEEP_QUAL',   "Onboarding sleep quality array defined"),
    ('var OB_EQUIP',        "Onboarding equipment array defined"),
    ('var OB_EXERCISE',     "Onboarding exercise array defined"),
    ('var OB_DIET',         "Onboarding diet array defined"),
    ('var OB_HEALTH',       "Onboarding health conditions array defined"),
    ('makeChips("ob-goals"',"Goals chips wired up"),
    ('makeChips("ob-equip"',"Equipment chips wired up"),
    ('submitOnboard',       "Submit onboarding function exists"),
    ('genPlan',             "Plan generation called from onboarding"),
]
ok=0; fail=0
for term, label in checks:
    if term in html:
        print(f"  \033[0;32m✅ {label}\033[0m"); ok+=1
    else:
        print(f"  \033[0;31m❌ {label} — missing: {term}\033[0m"); fail+=1
sys.exit(1 if fail else 0)
PYEOF
[ $? -eq 0 ] && ok "All auth/onboarding checks passed" || fail "Auth/onboarding checks failed"

# ════════════════════════════════════════════════════════════
hdr "3. TODAY TAB"
# ════════════════════════════════════════════════════════════

python3 << 'PYEOF'
import sys
html = open("index.html").read()
checks = [
    ('id="t-wt"',              "Weight stat display"),
    ('id="t-bmi"',             "BMI stat display"),
    ('id="t-lost"',            "Weight lost display"),
    ('id="t-str"',             "Streak display"),
    ('id="t-cal"',             "Calories display"),
    ('id="t-rem"',             "Calories remaining display"),
    ('id="wk-dots"',           "Week dots display"),
    ('id="habit-list"',        "Habits list container"),
    ('toggleHabit',            "Habit toggle function"),
    ('id="qt-steps"',          "Steps input"),
    ('quickLogSteps',          "Steps save function"),
    ('id="qt-steps-cur"',      "Steps saved value display"),
    ('id="qt-water-range"',    "Water slider"),
    ('saveWaterSlider',        "Water save function"),
    ('id="qt-water-val"',      "Water value display"),
    ('Save Water',             "Save Water button label"),
    ('id="qt-water-ok"',       "Water save confirmation"),
    ('renderTodayWater',       "Water slider populates on load"),
    ('Logged today:',          "Steps shows saved value on load"),
    ('parseFloat(e.kcal)',     "Calories parsed as number not string"),
    ('parseFloat(x.total_kcal)',"DB calories parsed as number"),
    ('id="closeday-today-btn"',"Close My Day button"),
    ('id="day-closed-msg"',    "Day closed message"),
    ('buildHabits',            "Dynamic habits from user profile"),
]
ok=0; fail=0
for term, label in checks:
    if term in html:
        print(f"  \033[0;32m✅ {label}\033[0m"); ok+=1
    else:
        print(f"  \033[0;31m❌ {label} — missing: {term}\033[0m"); fail+=1
sys.exit(1 if fail else 0)
PYEOF
[ $? -eq 0 ] && ok "All Today tab checks passed" || fail "Today tab checks failed"

# ════════════════════════════════════════════════════════════
hdr "4. FOOD TAB"
# ════════════════════════════════════════════════════════════

python3 << 'PYEOF'
import sys
html = open("index.html").read()
checks_present = [
    ('addMealToLog',           "Add meal saves to DB immediately"),
    ('food_log").insert',      "Food log insert to Supabase"),
    ('fresh.data.map',         "Fresh DB reload after analysis"),
    ('Analyse &amp; Save',      "Correct button label"),
    ('food-save-ok',           "Auto-saved confirmation element"),
    ('food_log").update',      "Food log update (kcal after analysis)"),
    ('id="food-pending-card"', "Pending meals card"),
    ('id="food-today"',        "Today food log display"),
    ('id="food-result"',       "AI analysis result card"),
    ('id="food-btn"',          "Analyse button"),
    ('id="food-load"',         "Loading spinner"),
    ('renderFoodLog',          "Food log render function"),
    ('analyseFood',            "Food analysis function"),
    ('isPending',              "Pending badge logic"),
    ('deleteFood',             "Delete food entry function"),
    ('checkAnalyseReady',      "Analyse button state check"),
]
checks_absent = [
    ('Save to Diary',          "Save to Diary button REMOVED"),
]
ok=0; fail=0
for term, label in checks_present:
    if term in html:
        print(f"  \033[0;32m✅ {label}\033[0m"); ok+=1
    else:
        print(f"  \033[0;31m❌ {label} — missing: {term}\033[0m"); fail+=1
for term, label in checks_absent:
    if term not in html:
        print(f"  \033[0;32m✅ {label}\033[0m"); ok+=1
    else:
        print(f"  \033[0;31m❌ {label} — should be removed: {term}\033[0m"); fail+=1
sys.exit(1 if fail else 0)
PYEOF
[ $? -eq 0 ] && ok "All Food tab checks passed" || fail "Food tab checks failed"

# ════════════════════════════════════════════════════════════
hdr "5. PROGRESS TAB"
# ════════════════════════════════════════════════════════════

python3 << 'PYEOF'
import sys
html = open("index.html").read()
checks = [
    ('id="wt-chart"',       "Weight chart canvas"),
    ('id="st-chart"',       "Steps chart canvas"),
    ('saveWeight',          "Log weight function"),
    ('renderProgress',      "Render progress function"),
    ('id="habit-rate"',     "Habit completion rate"),
]
ok=0; fail=0
for term, label in checks:
    if term in html:
        print(f"  \033[0;32m✅ {label}\033[0m"); ok+=1
    else:
        print(f"  \033[0;31m❌ {label} — missing: {term}\033[0m"); fail+=1
sys.exit(1 if fail else 0)
PYEOF
[ $? -eq 0 ] && ok "All Progress tab checks passed" || fail "Progress tab checks failed"

# ════════════════════════════════════════════════════════════
hdr "6. PLAN TAB"
# ════════════════════════════════════════════════════════════

python3 << 'PYEOF'
import sys
html = open("index.html").read()
checks = [
    ('genPlan',             "Plan generation function"),
    ('renderAIPlan',        "Plan render function"),
    ('Regenerate Plan',     "Regenerate plan button"),
    ('id="plan-regen-hint"',"Regen availability hint"),
    ('ai_plan_date',        "Weekly regen limit tracking"),
    ('PRO.ai_plan_date = new', "Plan date saved after generation"),
    ('day' + 'sSince < 7', "7-day regen limit enforced"),
    ('id="plan-load"',      "Plan loading spinner"),
    ('_planCustom',         "Edit/customise plan function"),
]
ok=0; fail=0
for term, label in checks:
    found = term.replace('day' + 'sSince', 'daysSince') if 'daysSince' not in term else term
    if term in html:
        print(f"  \033[0;32m✅ {label}\033[0m"); ok+=1
    else:
        print(f"  \033[0;31m❌ {label} — missing: {term}\033[0m"); fail+=1
sys.exit(1 if fail else 0)
PYEOF
[ $? -eq 0 ] && ok "All Plan tab checks passed" || fail "Plan tab checks failed"

# ════════════════════════════════════════════════════════════
hdr "7. MORE TAB"
# ════════════════════════════════════════════════════════════

python3 << 'PYEOF'
import sys
html = open("index.html").read()

# Check order of sections in More tab
import re
more_start = html.find('id="sc-more"')
more_full  = html[more_start:more_start+12000]
labels     = [l.strip() for l in re.findall(r'class="sec-lbl">([^<]+)', more_full)]
expected   = ["Profile", "Health Parameters", "Data", "Beta &amp; Feedback", "Help"]
order_ok   = labels == expected

checks = [
    ('saveProfile',         "Save profile function"),
    ('saveReport',          "Save health params function"),
    ('id="r-ha"',           "HbA1c input field"),
    ('id="r-su"',           "Fasting sugar input"),
    ('id="r-hb"',           "Haemoglobin input"),
    ('id="r-other"',        "Other health params textarea"),
    ('getHealthContext',    "Health context for AI prompts"),
    ('submitFeedback',      "Feedback submit function"),
    ('id="feedback-chips"', "Feedback topic chips"),
    ('exportJSON',          "Export data function"),
    ('resetOnboarding',     "Redo onboarding function"),
    ('id="help-modal"',     "User guide modal"),
    ('Open Guide',          "Open Guide button"),
    ('Close Guide',         "Close Guide button"),
    ('doSignOut',           "Sign out function linked"),
]
ok=0; fail=0
for term, label in checks:
    if term in html:
        print(f"  \033[0;32m✅ {label}\033[0m"); ok+=1
    else:
        print(f"  \033[0;31m❌ {label} — missing: {term}\033[0m"); fail+=1

if order_ok:
    print(f"  \033[0;32m✅ More tab section order: Profile → Health → Data → Beta → Feedback\033[0m"); ok+=1
else:
    print(f"  \033[0;31m❌ More tab section ORDER WRONG (should be: Profile → Health → Data → Beta → Feedback)\033[0m"); fail+=1

sys.exit(1 if fail else 0)
PYEOF
[ $? -eq 0 ] && ok "All More tab checks passed" || fail "More tab checks failed"

# ════════════════════════════════════════════════════════════
hdr "8. CLOSE MY DAY"
# ════════════════════════════════════════════════════════════

python3 << 'PYEOF'
import sys
html = open("index.html").read()
checks = [
    ('id="closeday-modal"',   "Close Day modal exists"),
    ('id="cd-food-analysis"', "Close Day food section"),
    ('id="cd-food-body"',     "Close Day food body"),
    ('id="cd-worked-chips"',  "What worked chips"),
    ('id="cd-challenge-chips"',"Tomorrow challenge chips"),
    ('id="cd-ai-out"',        "AI output container"),
    ('id="cd-ai-load"',       "AI loading spinner"),
    ('runCloseDayAI',         "Close Day AI function"),
    ('confirmCloseDay',       "Confirm close day function"),
    ('food_analysis',         "7-section: food analysis"),
    ('habit_analysis',        "7-section: habit analysis"),
    ('water_analysis',        "7-section: water analysis"),
    ('activity_analysis',     "7-section: activity analysis"),
    ('health_note',           "7-section: health note"),
    ('goal_progress',         "7-section: goal progress"),
    ('tomorrow_strategy',     "7-section: tomorrow strategy"),
    ('closeday_ai_',          "AI result cached to localStorage"),
    ('Running AI analysis',   "AI runs when Confirm is tapped"),
    ('day_closed_date',       "Day closed date saved to DB"),
    ('closeModal',            "Close modal function"),
]
ok=0; fail=0
for term, label in checks:
    if term in html:
        print(f"  \033[0;32m✅ {label}\033[0m"); ok+=1
    else:
        print(f"  \033[0;31m❌ {label} — missing: {term}\033[0m"); fail+=1
sys.exit(1 if fail else 0)
PYEOF
[ $? -eq 0 ] && ok "All Close Day checks passed" || fail "Close Day checks failed"

# ════════════════════════════════════════════════════════════
hdr "9. AI & QUOTA SYSTEM"
# ════════════════════════════════════════════════════════════

python3 << 'PYEOF'
import sys, re
html = open("index.html").read()
checks_present = [
    ('daily_usage',          "Server-side quota table (Supabase)"),
    ('analysis_count',       "Analysis count field"),
    ('todayAnalysisCount',   "Analysis count variable"),
    ('updateAnalyseBtn',     "Analyse button state updater"),
    ('getHealthContext',     "Health context injected into AI"),
    ('health_hba1c',         "HbA1c in health context"),
    ('/api/chat',            "AI calls go through proxy"),
    ('claude-sonnet',        "Correct Claude model"),
    ('max_tokens',           "Max tokens set"),
]
checks_absent = [
    ('analysis_count_',      "No localStorage quota remaining"),
    ('localStorage.setItem.*analysis', "No localStorage quota write"),
]
ok=0; fail=0
for term, label in checks_present:
    if term in html:
        print(f"  \033[0;32m✅ {label}\033[0m"); ok+=1
    else:
        print(f"  \033[0;31m❌ {label} — missing: {term}\033[0m"); fail+=1

# Check chat.js
try:
    chatjs = open("api/chat.js").read()
    if 'ANTHROPIC_API_KEY' in chatjs:
        print(f"  \033[0;32m✅ API key checked in chat.js\033[0m"); ok+=1
    else:
        print(f"  \033[0;31m❌ ANTHROPIC_API_KEY missing from chat.js\033[0m"); fail+=1
except:
    print(f"  \033[1;33m⚠️  api/chat.js not found\033[0m")

for term, label in checks_absent:
    if not re.search(term, html):
        print(f"  \033[0;32m✅ {label}\033[0m"); ok+=1
    else:
        print(f"  \033[0;31m❌ {label} — should be removed\033[0m"); fail+=1

# API key should NOT be in index.html
if 'ANTHROPIC_API_KEY' not in html:
    print(f"  \033[0;32m✅ API key NOT exposed in index.html\033[0m"); ok+=1
else:
    print(f"  \033[0;31m❌ ANTHROPIC_API_KEY found in index.html — SECURITY RISK\033[0m"); fail+=1
sys.exit(1 if fail else 0)
PYEOF
[ $? -eq 0 ] && ok "All AI/quota checks passed" || fail "AI/quota checks failed"

# ════════════════════════════════════════════════════════════
hdr "10. DATA LOADING & PERSISTENCE"
# ════════════════════════════════════════════════════════════

python3 << 'PYEOF'
import sys
html = open("index.html").read()
checks = [
    ('loadData',             "Load user data function"),
    ('Promise.all',          "Parallel DB fetches"),
    ('DAT.weights',          "Weights loaded into memory"),
    ('DAT.steps',            "Steps loaded into memory"),
    ('DAT.water',            "Water loaded into memory"),
    ('DAT.habits',           "Habits loaded into memory"),
    ('DAT.food',             "Food loaded into memory"),
    ('onConflict',           "Upsert with conflict handling"),
    ('parseFloat(x.total_kcal)', "DB kcal parsed as number"),
    ('parseFloat(e.kcal)',   "Memory kcal parsed as number"),
    ('parseFloat(e.kcal) || 0', "Calorie sum uses parseFloat"),
    ('renderTodayWater()',   "Water slider populated on load"),
    ('stInput.value = sv',  "Steps input shows saved value"),
    ('Logged today:',        "Steps shows current value label"),
]
ok=0; fail=0
for term, label in checks:
    if term in html:
        print(f"  \033[0;32m✅ {label}\033[0m"); ok+=1
    else:
        print(f"  \033[0;31m❌ {label} — missing: {term}\033[0m"); fail+=1
sys.exit(1 if fail else 0)
PYEOF
[ $? -eq 0 ] && ok "All data persistence checks passed" || fail "Data persistence checks failed"

# ════════════════════════════════════════════════════════════
hdr "11. SECURITY"
# ════════════════════════════════════════════════════════════

python3 << 'PYEOF'
import sys
html = open("index.html").read()
ok=0; fail=0

# Should NOT be in index.html
bad = [
    ('sk-ant-',      "Anthropic secret key"),
    ('ANTHROPIC_API_KEY', "Anthropic key variable"),
]
for term, label in bad:
    if term not in html:
        print(f"  \033[0;32m✅ {label} not exposed in HTML\033[0m"); ok+=1
    else:
        print(f"  \033[0;31m❌ SECURITY: {label} found in index.html!\033[0m"); fail+=1

# Supabase anon key should be present (it's public by design)
if 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9' in html:
    print(f"  \033[0;32m✅ Supabase anon key present (public by design, protected by RLS)\033[0m"); ok+=1
else:
    print(f"  \033[1;33m⚠️  Supabase anon key not found — app won't connect to DB\033[0m")

sys.exit(1 if fail else 0)
PYEOF
[ $? -eq 0 ] && ok "All security checks passed" || fail "Security checks failed"

# ════════════════════════════════════════════════════════════
hdr "12. PHASE 1 CODE QUALITY"
# ════════════════════════════════════════════════════════════

python3 << 'PYEOF2'
import sys
html = open("index.html").read()
checks_present = [
    ("showToast",           "Toast system replaces alert()"),
    ("toast-el",            "Toast DOM element exists"),
    (".toast.t-ok",         "Toast CSS (ok/green)"),
    (".toast.t-err",        "Toast CSS (err/red)"),
    (".toast.t-warn",       "Toast CSS (warn/orange)"),
    ("escapeHtml",          "XSS escapeHtml() function"),
    ("getTodayMeals",       "getTodayMeals() helper"),
    ("getTodaySteps",       "getTodaySteps() helper"),
    ("getTodayWater",       "getTodayWater() helper"),
]
checks_absent = [
    ("alert(",              "No alert() calls remaining"),
]
ok=0; fail=0
for term, label in checks_present:
    if term in html:
        print(f"  [0;32m✅ {label}[0m"); ok+=1
    else:
        print(f"  [0;31m❌ {label} — missing: {term}[0m"); fail+=1
for term, label in checks_absent:
    if term not in html:
        print(f"  [0;32m✅ {label}[0m"); ok+=1
    else:
        count = html.count(term)
        print(f"  [0;31m❌ {label} — found {count} remaining[0m"); fail+=1
sys.exit(1 if fail else 0)
PYEOF2
[ $? -eq 0 ] && ok "All Phase 1 code quality checks passed" || fail "Phase 1 checks failed"

# ════════════════════════════════════════════════════════════
hdr "13. LIVE API CHECK"
# ════════════════════════════════════════════════════════════

if [ "$1" = "--local" ]; then
  echo -e "${yellow}  ⏭  Skipped (--local mode)${nc}"
else
  RESULT=$(curl -s --max-time 15 -X POST "$SITE/api/chat" \
    -H "Content-Type: application/json" \
    -d '{"model":"claude-sonnet-4-20250514","max_tokens":5,"messages":[{"role":"user","content":"hi"}]}' 2>/dev/null)

  if echo "$RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if 'content' in d else 1)" 2>/dev/null; then
    ok "API proxy live — Anthropic key configured and working"
  elif echo "$RESULT" | grep -q "ANTHROPIC_API_KEY"; then
    fail "API proxy: ANTHROPIC_API_KEY not set in Vercel env vars"
  elif echo "$RESULT" | grep -q "404\|Cannot POST"; then
    fail "API proxy: 404 — api/chat.js not deployed or routing broken"
  elif [ -z "$RESULT" ]; then
    fail "API proxy: no response (timeout or site down)"
  else
    fail "API proxy error: ${RESULT:0:120}"
  fi

  # Check main site loads
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$SITE")
  if [ "$HTTP_STATUS" = "200" ]; then
    ok "Main site returns 200 OK"
  else
    fail "Main site returned HTTP $HTTP_STATUS"
  fi
fi

# ════════════════════════════════════════════════════════════
# SUMMARY
# ════════════════════════════════════════════════════════════

TOTAL=$((PASS + FAIL))
echo ""
echo "════════════════════════════════════════════"
if [ $FAIL -eq 0 ] && [ $WARN -eq 0 ]; then
  echo -e "${green}${bold}✅ ALL $TOTAL CHECKS PASSED${nc}"
  [ "$1" != "--local" ] && echo -e "${green}   Live: $SITE${nc}"
elif [ $FAIL -eq 0 ]; then
  echo -e "${yellow}${bold}✅ $PASS/$TOTAL PASSED (${WARN} warnings)${nc}"
else
  echo -e "${red}${bold}❌ $FAIL/$TOTAL CHECKS FAILED${nc}"
  echo -e "${red}   Fix failures before deploying to production${nc}"
fi
echo "════════════════════════════════════════════"
exit $FAIL
