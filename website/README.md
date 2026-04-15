# FitMe Marketing Website

Pre-launch marketing site for the FitMe iOS app.

## Stack

- **Framework:** Astro
- **Styling:** Tailwind CSS
- **Hosting:** Vercel (not yet the primary deployed surface)

## Sections

- Hero with app value proposition
- Features overview (Training, Nutrition, Recovery, AI, Privacy)
- Screenshots gallery (placeholder)
- How It Works (3-step flow)
- Privacy & Security
- FAQ
- App Store CTA

## Status

The website code builds successfully but has **launch blockers**:

- Placeholder GA4 measurement IDs
- Placeholder App Store links
- Unverified aggregate-rating structured data

The canonical Vercel project (`fit-tracker2`) currently serves the operations dashboard from `dashboard/`. The marketing website will replace it as the primary public surface once launch blockers are resolved.

## Development

```bash
npm install
npm run dev      # Start dev server
npm run build    # Production build
```
