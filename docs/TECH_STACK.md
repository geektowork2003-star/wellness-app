# Tech Stack, Deployment & Infrastructure Guide
## Reusable Reference for Single-File PWA Projects

---

## 1. Architecture Pattern

**"Zero-Build Single-File PWA"** — entire frontend in one HTML file, one serverless function for secure API proxy, managed backend-as-a-service.

```
Browser (PWA)
    │
    ├── index.html (HTML + CSS + JS, ~100-150KB)
    │       └── Supabase JS (CDN) ──► Supabase (Auth + DB)
    │
    └── /api/chat.js (Vercel Serverless)
                └── Anthropic API (server-side key)
```

---

## 2. Tech Stack

### Frontend
| Layer | Choice | Why |
|-------|--------|-----|
| Language | Vanilla JS / HTML5 / CSS3 | No build step, no dependencies, works forever |
| Fonts | Google Fonts (DM Sans, DM Serif Display) | Free, CDN-served |
| Charts | Chart.js (CDN) | Lightweight, no install |
| PWA | manifest.json + sw.js | Installable on Android/iOS, offline-capable |
| State | In-memory JS objects | Simple, fast, no framework needed |

### Backend
| Layer | Choice | Why |
|-------|--------|-----|
| Database | Supabase (PostgreSQL) | Free tier, built-in auth, RLS, JS client |
| Auth | Supabase Auth | JWT, email/password, social logins available |
| API Proxy | Vercel Serverless (Node.js) | Hides API keys, free, auto-scaled |
| Hosting | Vercel | Free static hosting, CDN, custom domains |
| AI | Anthropic Claude Sonnet | Best instruction-following, JSON output |

---

## 3. Prerequisite Accounts

| Service | URL | Free Tier |
|---------|-----|-----------|
| Supabase | supabase.com | 500MB DB, 50K MAU, 2 projects |
| Vercel | vercel.com | Unlimited static, 100GB bandwidth, 100K function invocations/mo |
| Anthropic | console.anthropic.com | $5 free credits on signup |
| GitHub | github.com | Unlimited private repos |

**Total cost to start: $0**

---

## 4. Infrastructure Cost Methodology

### Cost Drivers
1. **Supabase** — fixed cost, not per-user until 50K MAU
2. **Vercel** — fixed cost, free unless >100K function calls/day
3. **Anthropic API** — pure variable, per-token, per-user

### Formula
```
Monthly cost = Supabase_tier + Vercel_tier + (users × daily_calls × cost_per_call × 30)

Cost per AI call (Claude Sonnet):
  Input:  $3.00 / 1M tokens
  Output: $15.00 / 1M tokens
  
  Avg call (food analysis): 1,500 input + 800 output tokens
  = (1500 × 0.000003) + (800 × 0.000015)
  = $0.0045 + $0.012 = ~$0.017 per call (~₹1.4)

  3 calls/user/day = ~₹4.2/user/day = ~₹126/user/month
```

### Scale Model
| Users | Supabase | Vercel | API (3 calls/day) | Total/mo |
|-------|----------|--------|-------------------|----------|
| 50 | $0 | $0 | $76 (~₹6,400) | ~₹6,400 |
| 100 | $0 | $0 | $153 (~₹12,900) | ~₹12,900 |
| 500 | $25 | $0 | $765 (~₹64,300) | ~₹66,400 |
| 1000 | $25 | $0 | $1,530 (~₹1,28,500) | ~₹1,30,600 |

### Viability Pricing
```
Min subscription = (Monthly infra cost / users) × safety_margin(2.5x)

At 100 users: ₹12,900 / 100 × 2.5 = ₹323/user
At 1000 users: ₹1,30,600 / 1000 × 2.5 = ₹327/user

Recommended: ₹149–₹299/month
(users won't use all 3 AI calls every day — real usage ~40-60% of theoretical max)
```

---

## 5. Deployment Steps

```bash
# Prerequisites
npm install -g vercel

# 1. Project structure
mkdir my-project && cd my-project
mkdir api
# Place index.html, api/chat.js, manifest.json, sw.js, vercel.json

# 2. Add API key to Vercel
vercel env add ANTHROPIC_API_KEY production

# 3. Deploy
vercel --prod --yes

# 4. Custom domain (optional)
vercel domains add myapp.com
```

---

## 6. Security Checklist

- [ ] Anthropic API key stored in Vercel env vars only (never in HTML)
- [ ] Supabase Row Level Security enabled on all tables
- [ ] All tables have `auth.uid() = user_id` policies
- [ ] GitHub repo set to **private** (Supabase anon key is in HTML)
- [ ] `.gitignore` includes `.env.local`, `deploy.py`, `.DS_Store`
- [ ] Vercel function validates request method (reject non-POST)

---

## 7. Scaling Triggers

| Threshold | Action |
|-----------|--------|
| >500 users | Upgrade Supabase to Pro ($25/mo) |
| >10K function calls/day | Monitor Vercel usage, may need Pro |
| >2 AI calls/user/day avg | Consider caching responses or raising subscription price |
| Need payments | Integrate Razorpay (India) or Stripe (global) |
