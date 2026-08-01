# Mealgram landing — Cloudflare Pages

Static site for `mealgram.xyz`. Four pages — `/`, `/privacy.html`, `/support.html`, `/terms.html`.
No build step, pure HTML + inline CSS + Manrope from Google Fonts.

## Files

```
landing/
├── index.html          Hero + features + premium + privacy callout
├── privacy.html        Privacy Policy (GDPR + Apple-compliant)
├── support.html        FAQ + contact mailto
├── terms.html          Terms of Use / EULA for App Store subscriptions
├── _headers            Security + cache (CF Pages parses this)
├── _redirects          Vanity URLs (CF Pages parses this)
└── assets/
    ├── icon.png        1024×1024 app icon (no alpha)
    └── logo.svg        Original brand SVG
```

## Deploy to Cloudflare Pages

### Option A — via Git (recommended, auto-deploys on push)

1. Push the repo to GitHub (you've already done this — origin `bashyrov/mealgram-app`).
2. https://pages.cloudflare.com → **Create a project** → **Connect to Git** → select `mealgram-app`.
3. **Build settings:**
   - Framework preset: **None**
   - Build command: *(leave empty)*
   - Build output directory: `landing`
   - Root directory: *(leave empty)*
4. **Save and Deploy** — Cloudflare builds and gives you a `*.pages.dev` URL in ~30 seconds.

### Option B — direct upload (no Git)

1. Zip the `landing/` folder.
2. CF Pages → **Upload assets** → drag the zip.

### Custom domain

1. CF Pages project → **Custom domains** → **Set up a custom domain**.
2. Enter `mealgram.xyz` (and optionally `www.mealgram.xyz`).
3. CF gives DNS records to add. If your domain is already on Cloudflare DNS, it sets them automatically.

That's it — TLS, CDN, DDoS, HTTP/3 included free.

## Local preview

Any static server works. Quickest:

```bash
cd landing
python3 -m http.server 8000
# → http://localhost:8000
```

Or Node:

```bash
npx serve landing
```

## Update flow

- Content tweak → edit HTML → commit → CF auto-deploys in ~30s.
- New screenshot → drop in `assets/` → reference from index.html → commit.
- A/B test? CF Pages **Preview deployments** for every PR — no production impact.

## Cost

$0/mo until you cross 500 MB bandwidth + 100K requests/day. Then $5/mo Pages Pro. You won't hit those for a long time.
