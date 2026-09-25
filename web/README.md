# Fitgram public pages

Markdown source for the public Fitgram pages Apple requires for App Store submission:

- `privacy.md` → host at `https://fitgram.space/privacy`
- `support.md` → host at `https://fitgram.space/support`
- `terms.md` → host at `https://fitgram.space/terms`

## Hosting options (pick one)

### A. GitHub Pages (free, ~5 min)

1. Push this `web/` folder to a public GitHub repo.
2. Enable Pages → source: `main` branch → folder: `/web`.
3. Add a CNAME file pointing `fitgram.space` at `<user>.github.io` (or use `fitgram-space.github.io/web/privacy`).

### B. Notion (zero-dev, also free)

1. Create a Notion page, paste each `.md` body in.
2. Share → "Publish to web" → enable.
3. Use Notion's public URL until you have a real domain.

### C. Cloudflare Pages

1. Push the repo, connect via Cloudflare Pages.
2. Set `fitgram.space` as custom domain. SSL is automatic.

## Apple-side: enter these URLs

In App Store Connect → your app → App Information:

- **Privacy Policy URL**: `https://fitgram.space/privacy`
- **Support URL**: `https://fitgram.space/support`
- **Terms of Use / EULA URL**: `https://fitgram.space/terms`
- **Marketing URL** (optional): `https://fitgram.space`

Then re-submit for review.

## Updating

After material changes, bump the "Last updated" line at the top of the `.md` and push. Old links keep working.
