#!/bin/bash
# ============================================================
# Wellness App — Eval Script
# Run after every deploy: bash eval.sh
# Run before deploy: bash eval.sh --local
# ============================================================

SITE="https://wellness-final.vercel.app"
HTML="index.html"
PASS=0
FAIL=0

green='\033[0;32m'
red='\033[0;31m'
yellow='\033[1;33m'
nc='\033[0m'

ok()   { echo -e "${green}✅ $1${nc}"; ((PASS++)); }
fail() { echo -e "${red}❌ $1${nc}"; ((FAIL++)); }
info() { echo -e "${yellow}── $1${nc}"; }

# ── Check file exists ─────────────────────────────────────
if [ ! -f "$HTML" ]; then
  echo -e "${red}❌ index.html not found. Run from wellness-final directory.${nc}"
  exit 1
fi

info "LEVEL 1: Static checks on $HTML"
echo ""

# ── 1. JS syntax ──────────────────────────────────────────
# Extract JS from HTML and check syntax
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
  fail "JS syntax BROKEN — fix before deploying"
fi

# ── 2. File size ──────────────────────────────────────────
SIZE=$(wc -c < "$HTML")
if [ "$SIZE" -gt 100000 ] && [ "$SIZE" -lt 220000 ]; then
  ok "HTML size: ${SIZE} bytes"
else
  fail "HTML size suspicious: ${SIZE} bytes (expected 100K-220K)"
fi

# ── 3. Feature checks ─────────────────────────────────────
python3 << 'PYEOF'
import sys
html = open("index.html").read()
checks = [
    ("var OB_GOALS",        True,  "Onboarding goals array"),
    ("var OB_SLEEP_QUAL",   True,  "Sleep quality array"),
    ("var OB_EQUIP",        True,  "Equipment array"),
    ("signOut().then",      True,  "Sign out works on mobile"),
    ("closeday-modal",      True,  "Close Day modal HTML"),
    ("cd-food-analysis",    True,  "Close Day food section"),
    ("Analyse & Save",      True,  "Correct analyse button label"),
    ("Save to Diary",       False, "Save to Diary button removed"),
    ("daily_usage",         True,  "Server-side quota (Supabase)"),
    ("analysis_count_",     False, "No localStorage quota"),
    ("getHealthContext",     True,  "Health context injection"),
    ("buildHabits",         True,  "Dynamic habits"),
    ("runCloseDayAI",       True,  "Close Day AI function"),
    ("food_analysis",       True,  "Close Day food analysis"),
    ("habit_analysis",      True,  "Close Day habit analysis"),
    ("water_analysis",      True,  "Close Day water analysis"),
    ("activity_analysis",   True,  "Close Day activity analysis"),
    ("addMealToLog",        True,  "Add meal saves immediately"),
    ("fresh.data.map",      True,  "Food reload after analysis"),
    ("renderTodayWater",    True,  "Water slider render"),
    ("ANTHROPIC_API_KEY",   False, "API key NOT in index.html"),
    ("submitFeedback",      True,  "Feedback function"),
    ("todayAnalysisCount",  True,  "Analysis count variable"),
    ("isPending",           True,  "Pending badge logic"),
    ("id=\"boot\"",         True,  "Boot screen (no sign-in flash)"),
    ("db.auth.signOut",     True,  "Sign out function"),
]
passed = 0
failed = 0
for term, should, label in checks:
    found = term in html
    if found == should:
        print(f"  \033[0;32m✅ {label}\033[0m")
        passed += 1
    else:
        print(f"  \033[0;31m❌ {label} — {'missing' if should else 'should be removed'}: {term}\033[0m")
        failed += 1
print(f"\n  {passed} passed, {failed} failed")
sys.exit(0 if failed == 0 else 1)
PYEOF

if [ $? -eq 0 ]; then
  ok "All feature checks passed"
else
  fail "Some feature checks failed"
fi

echo ""

# ── 4. API proxy check (skip if --local flag) ─────────────
if [ "$1" != "--local" ]; then
  info "LEVEL 2: Live API check"
  echo ""
  RESULT=$(curl -s --max-time 10 -X POST "$SITE/api/chat" \
    -H "Content-Type: application/json" \
    -d '{"model":"claude-sonnet-4-20250514","max_tokens":5,"messages":[{"role":"user","content":"hi"}]}' \
    2>/dev/null)

  if echo "$RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if 'content' in d else 1)" 2>/dev/null; then
    ok "API proxy working — Anthropic key configured"
  elif echo "$RESULT" | grep -q "ANTHROPIC_API_KEY"; then
    fail "API proxy: ANTHROPIC_API_KEY not set in Vercel env vars"
  elif echo "$RESULT" | grep -q "404"; then
    fail "API proxy: 404 — api/chat.js not deployed correctly"
  else
    fail "API proxy error: $RESULT"
  fi
  echo ""
fi

# ── Summary ───────────────────────────────────────────────
echo "════════════════════════════════"
TOTAL=$((PASS + FAIL))
if [ $FAIL -eq 0 ]; then
  echo -e "${green}✅ ALL $TOTAL CHECKS PASSED${nc}"
  if [ "$1" != "--local" ]; then
    echo -e "${green}   App is live and healthy at $SITE${nc}"
  fi
else
  echo -e "${red}❌ $FAIL/$TOTAL CHECKS FAILED — investigate before deploying${nc}"
fi
echo "════════════════════════════════"

exit $FAIL
