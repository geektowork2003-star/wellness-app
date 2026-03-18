# Wellness App — How To Guide
## Deploy · Test · Git · SQL Tweaks

---

## Quick Reference Card

| Task | Command |
|------|---------|
| Deploy latest code | `python3 deploy.py` |
| Check without deploying | `python3 deploy.py --check` |
| Run eval after deploy | `bash eval.sh` |
| Push to GitHub | `git add . && git commit -m "message" && git push` |
| Reset AI quota (testing) | `delete from daily_usage where date = current_date;` |
| Reset Close Day (testing) | `update profiles set day_closed_date = null where id = (select id from auth.users where email = 'x@x.com');` |
| Reset onboarding | `update profiles set onboarded = false where id = (...)` |

---

## 1. Files in Your Project

```
wellness-final/
├── index.html          ← Entire app (~150KB). Edit this via Claude.
├── api/
│   └── chat.js         ← Anthropic API proxy. Rarely needs changing.
├── manifest.json       ← PWA settings (name, icon, colours)
├── sw.js               ← Service worker (caching). Rarely needs changing.
├── vercel.json         ← Routing rules. Rarely needs changing.
├── deploy.py           ← Deploy script. Run this to deploy.
├── eval.sh             ← Eval/test script. Runs automatically inside deploy.py.
├── EVAL_CHECKLIST.md   ← Manual testing checklist (browser steps)
├── HOWTO.md            ← This file
└── .vercel/            ← Vercel project link (auto-generated, don't edit)
```

**Rule of thumb:** You only ever edit `index.html`. Everything else is infrastructure.

---

## 2. How to Deploy

### Standard deploy (most common)
```bash
cd ~/wellness-final
python3 deploy.py
```

This does three things automatically:
1. Writes the latest `index.html` from embedded code
2. Runs `eval.sh --local` — checks 26 things (syntax, features, removed buttons etc.)
3. If all green → deploys to Vercel

### Deploy without running eval (emergency only)
```bash
cd ~/wellness-final
python3 deploy.py --force
```

### Check only (no deploy)
```bash
cd ~/wellness-final
python3 deploy.py --check
```

### Manual deploy (if deploy.py has issues)
```bash
cd ~/wellness-final
vercel --prod --yes --force
```

### After deploy — verify live site
```bash
cd ~/wellness-final
bash eval.sh
```
This runs all checks + tests the live API. Should show all green.

---

## 3. How to Run the Eval

### Before deploying (local check, 30 seconds)
```bash
cd ~/wellness-final
bash eval.sh --local
```

### After deploying (checks live site too)
```bash
cd ~/wellness-final
bash eval.sh
```

### What the eval checks
- JS syntax is clean
- File size is reasonable (100KB–220KB)
- 26 specific features present/absent (goals array, sign out fix, no Save to Diary button, server-side quota, etc.)
- Live API proxy returns a response from Anthropic

### If eval fails
The output tells you exactly which check failed, e.g.:
```
❌ Save to Diary button removed — should be removed: Save to Diary
```
Fix that in `index.html` then re-run `deploy.py`.

---

## 4. How to Push to GitHub

### First time setup (already done — skip if repo exists)
```bash
cd ~/wellness-final
git init
git remote add origin https://github.com/geektowork2003-star/wellness-app.git
```

### Regular push after changes
```bash
cd ~/wellness-final

# Stage all changed files
git add .

# Commit with a meaningful message
git commit -m "Fix food analysis auto-save"

# Push to GitHub
git push
```

### If push asks for password
GitHub uses Personal Access Tokens, not passwords:
1. Go to `github.com` → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate new token → tick `repo` → copy token
3. Use token as password when prompted

### What to commit
```bash
# Commit everything except secrets and build files
git add index.html api/chat.js manifest.json sw.js vercel.json
git add deploy.py eval.sh
git add *.md  ← all documentation files
git commit -m "your message"
git push
```

### Check what's changed before committing
```bash
git status        # shows changed files
git diff          # shows exact changes
git log --oneline # shows commit history
```

---

## 5. SQL Tweaks for Testing

Go to: **Supabase → SQL Editor → New Query → paste → Run**

### Reset AI analysis quota (most common during testing)
```sql
-- Reset everyone today
delete from daily_usage where date = current_date;

-- Reset one user only
delete from daily_usage
where date = current_date
  and user_id = (select id from auth.users where email = 'your@email.com');
```

### Reset Close My Day flag
```sql
-- Reset one user
update profiles
set day_closed_date = null
where id = (select id from auth.users where email = 'your@email.com');

-- Reset everyone
update profiles set day_closed_date = null where day_closed_date = current_date;
```

### Reset onboarding (to test fresh sign-up flow)
```sql
-- One user
update profiles
set onboarded = false
where id = (select id from auth.users where email = 'your@email.com');

-- Everyone (careful — resets all family members)
update profiles set onboarded = false;
```

### Delete a user completely (e.g. sister testing)
```sql
-- Get user ID first
select id from auth.users where email = 'sister@email.com';

-- Delete all their data (paste UUID from above)
delete from food_log       where user_id = 'UUID';
delete from daily_logs     where user_id = 'UUID';
delete from habits         where user_id = 'UUID';
delete from weights        where user_id = 'UUID';
delete from steps          where user_id = 'UUID';
delete from water          where user_id = 'UUID';
delete from health_reports where user_id = 'UUID';
delete from daily_usage    where user_id = 'UUID';
delete from profiles       where id      = 'UUID';
-- Then delete from Auth: Supabase → Authentication → Users → find user → Delete
```

### Fix duplicate food entries
```sql
delete from food_log a
using food_log b
where a.ctid > b.ctid
  and a.user_id = b.user_id
  and a.date = b.date
  and a.meal = b.meal;
```

### Check what a user has logged today
```sql
select meal, description, total_kcal, created_at
from food_log
where user_id = (select id from auth.users where email = 'your@email.com')
  and date = current_date
order by created_at;
```

### Check someone's profile settings
```sql
select preferred_name, start_weight, goal_weight, calorie_target,
       onboarded, day_closed_date, promo_code
from profiles
where id = (select id from auth.users where email = 'your@email.com');
```

### View today's AI usage across all users
```sql
select u.email, d.analysis_count, d.date
from daily_usage d
join auth.users u on u.id = d.user_id
where d.date = current_date
order by d.analysis_count desc;
```

### Apply a promo code manually to a user
```sql
update profiles
set promo_code = 'WELLNESS2025'
where id = (select id from auth.users where email = 'your@email.com');
```

### Reset everything for a clean test day (your account)
```sql
-- Run these one by one
delete from daily_usage    where user_id = (select id from auth.users where email = 'your@email.com') and date = current_date;
delete from food_log       where user_id = (select id from auth.users where email = 'your@email.com') and date = current_date;
delete from habits         where user_id = (select id from auth.users where email = 'your@email.com') and date = current_date;
delete from daily_logs     where user_id = (select id from auth.users where email = 'your@email.com') and date = current_date;
update profiles set day_closed_date = null where id = (select id from auth.users where email = 'your@email.com');
```

---

## 6. Adding the Anthropic API Key to Vercel

If you get "ANTHROPIC_API_KEY not configured" after a fresh deployment:

```bash
cd ~/wellness-final

# Add the key
vercel env add ANTHROPIC_API_KEY production
# Paste your sk-ant-... key when prompted

# Redeploy to pick it up
vercel --prod --yes --force
```

**Get the key from:** `console.anthropic.com` → API Keys

**Verify it's set:**
```bash
vercel env ls production
# Should show ANTHROPIC_API_KEY in the list
```

---

## 7. Common Problems & Fixes

| Problem | Fix |
|---------|-----|
| Old app still showing | Run `bash eval.sh` to check if deploy succeeded. Clear browser cache: Cmd+Shift+R |
| Sign out not working on mobile | Check `signOut().then` is in index.html: `grep "signOut" index.html` |
| Onboarding chips blank (goals/equipment) | Check `var OB_GOALS` in index.html: `grep "OB_GOALS" index.html` |
| Analysis fails: API key not configured | Run `vercel env ls production` — add key if missing |
| Food entries not saving | Open browser F12 → Console — look for red errors after "+ Add Meal" |
| Close Day button does nothing | Open F12 → Console — look for null reference errors |
| Eval shows ❌ JS syntax | Run `node --check /tmp/eval_check.js` to see exact error line |
| deploy.py says "project not found" | Run `rm -rf .vercel && vercel --prod --yes` to re-link |
| Duplicate food entries | Run the duplicate cleanup SQL (section 5 above) |

---

## 8. Starting a New Conversation with Claude

When you start a new Claude conversation to continue work on this app:

1. Share the `index.html` file (or the zip)
2. Tell Claude: *"This is a wellness PWA. The current index.html is attached. [describe what you want to change]"*
3. Claude will patch the file and give you a new `deploy.py`
4. Run `python3 deploy.py` to deploy

**Useful context to give Claude:**
- Supabase URL: `https://mmnmtwltqxrqijxjdcce.supabase.co`
- Live URL: `https://wellness-final.vercel.app`
- Stack: vanilla HTML/JS, Supabase, Vercel serverless, Anthropic Claude Sonnet
- Deploy method: `python3 deploy.py` (includes eval)
