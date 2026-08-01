# Mealgram public pages

Markdown source for the public pages Apple requires for App Store submission:

- `privacy.md` → host at `https://mealgram.xyz/privacy`
- `support.md` → host at `https://mealgram.xyz/support`
- `terms.md` → host at `https://mealgram.xyz/terms`

## Hosting options (pick one)

### A. GitHub Pages (free, ~5 min)

1. Push this `web/` folder to a public GitHub repo.
2. Enable Pages → source: `main` branch → folder: `/web`.
3. Add a CNAME file pointing `mealgram.xyz` at `<user>.github.io` (or use `mealgram-xyz.github.io/web/privacy`).

### B. Notion (zero-dev, also free)

1. Create a Notion page, paste each `.md` body in.
2. Share → "Publish to web" → enable.
3. Use Notion's public URL until you have a real domain.

### C. Cloudflare Pages

1. Push the repo, connect via Cloudflare Pages.
2. Set `mealgram.xyz` as custom domain. SSL is automatic.

## Apple-side: enter these URLs

In App Store Connect → your app → App Information:

- **Privacy Policy URL**: `https://mealgram.xyz/privacy`
- **Support URL**: `https://mealgram.xyz/support`
- **Terms of Use / EULA URL**: `https://mealgram.xyz/terms`
- **Marketing URL** (optional): `https://mealgram.xyz`

Then re-submit for review.

## Updating

After material changes, bump the "Last updated" line at the top of the `.md` and push. Old links keep working.
