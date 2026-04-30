# Recording the FitMe Hero GIF

A 30–60 second animated demo at the top of the README is the single highest-impact visual change for the repo. Recruiters and engineers click through, see the app actually working, and decide whether to keep reading. Industry research consistently shows a hero GIF/video is worth more than the next ten lines of text combined.

This guide covers what to record, how to record it on macOS, how to compress to a GitHub-friendly size, and how to drop it into the README.

---

## Output specs (target)

| Spec | Value |
| ---- | ----- |
| Format | Animated GIF |
| Width | 320–400px (mobile-aspect renders cleanly in README at this size) |
| Frame rate | 15–20fps (smooth without bloating size) |
| Duration | 30–60s |
| File size | **< 2MB**, ideally < 1MB (GitHub allows up to ~10MB but READMEs render slowly above 2MB) |
| Filename | `hero.gif` (lowercase, no spaces) |
| Path | `docs/media/hero.gif` |

---

## What to record (suggested flow)

A "show, don't tell" sequence covering 3–4 of FitMe's strongest screens. End on the Today screen for visual closure.

1. **Today screen** (5–8s) — let the ReadinessCard auto-cycle through 2–3 panels (readiness, training chart, nutrition snapshot).
2. **Training tab** (10–15s) — tap Start Training → log one set with weight + reps + RPE → tap Done.
3. **Nutrition tab** (10–15s) — tap Add Meal → use a template or quick-log → tap Save.
4. **Stats tab** (5–8s) — change period (Daily → Weekly → Monthly).
5. **Back to Today screen** (3–5s) — closes the loop visually.

Avoid: long animations, navigation hesitation, debugging UI artifacts, simulator chrome (use device-frame mode if Kap supports it).

---

## Recording (option A: Kap — recommended)

[Kap](https://getkap.co) is a free Mac screen recorder that exports directly to GIF.

1. **Install Kap**: `brew install --cask kap`  (or download from https://getkap.co)
2. **Open the simulator**:
   ```bash
   open FitTracker.xcodeproj
   # In Xcode: select iPhone 15 Pro simulator, then press ⌘R to build + run
   ```
3. **Frame the simulator** so it's visible on screen.
4. **Open Kap** (menu bar) → drag the rectangle to fit *only* the simulator screen (not the chrome around it).
5. **Click Record**. Run through the flow above.
6. **Stop** → Export as GIF → choose **15fps**, width **400** → **Export**.
7. Move the file: `mv ~/Downloads/your-recording.gif docs/media/hero.gif`

If the resulting GIF is over 2MB, see the **Compression** section below.

---

## Recording (option B: QuickTime + Gifski)

Use this if Kap doesn't suit. QuickTime is built-in; Gifski is a free converter.

1. **Install Gifski**: `brew install --cask gifski` (or App Store)
2. **Record with QuickTime**:
   - Open QuickTime Player
   - File → New Screen Recording (⌃⌘N)
   - Click the dropdown next to the record button → "Selection" → drag over the simulator
   - Record the flow → stop → save as `~/Desktop/fitme-demo.mov`
3. **Convert to GIF with Gifski**:
   - Open Gifski
   - Drag `fitme-demo.mov` into the window
   - Settings: **Width 400**, **Quality ~85**, **FPS 15**
   - Export → choose `docs/media/hero.gif`

---

## Compression (if file is too large)

If the exported GIF is over 2MB:

1. **Reduce width**: re-export at 320px or 280px (each step cuts size ~30–40%)
2. **Reduce frame rate**: 12fps still feels smooth for app demos; 10fps is the floor before it looks choppy
3. **Trim duration**: cut any dead frames at the start/end
4. **Use [Gifsicle](https://www.lcdf.org/gifsicle/)** to compress an existing GIF without re-recording:
   ```bash
   brew install gifsicle
   gifsicle -O3 --lossy=80 hero-large.gif -o hero.gif
   ```
   The `--lossy=80` flag typically cuts size 40–60% with minimal visible quality loss.
5. **Split into multiple smaller GIFs** if you can't get under 2MB — embed two side-by-side instead of one long one.

---

## Adding the hero to the README

Once `docs/media/hero.gif` exists, add this block to [README.md](../../README.md) directly under the `# FitMe` H1 (and above the bold tagline):

```markdown
<p align="center">
  <img src="docs/media/hero.gif" alt="FitMe in action — Today, Training, Nutrition, Stats" width="360">
</p>
```

Commit with:
```bash
git add docs/media/hero.gif README.md
git commit -m "feat(readme): add hero GIF demo"
git push -u origin <branch>
gh pr create --title "feat(readme): add hero GIF demo" --body "Adds the long-promised animated demo at the top of the README."
```

The Vercel preview will render the README with the GIF visible.

---

## Tips

- **Record on a clean simulator** — reset content/settings before recording so the demo isn't littered with stale data.
- **Mute notifications** on your Mac before recording (Do Not Disturb) so no system overlays leak into the capture.
- **Use the iPhone 15 Pro simulator** — it has the best aspect ratio for hero GIFs at 360px width.
- **Iterate** — recording 5–10 takes is normal. The first take will feel awkward; the third will feel natural.
- **Test on GitHub** — the rendered file at https://github.com/Regevba/FitTracker2/blob/main/README.md is what recruiters see. Verify it autoplays and isn't pixelated.
- **Re-record when the UI changes** — the hero is a snapshot of the current product. After major UX changes, plan for a 30-minute re-record session.

---

## Why this matters

From the recruiter best-practices research that drove the v1 README trim:

> 84% of employers want to see a working app, not just code. For iOS, where reviewers can't `npm start`, the substitutes ranked by effort/payoff: TestFlight public link → 30–60s screen-recorded demo video → Hero GIF + 4–6 annotated screenshots → static screenshots → nothing.

A GIF at the top of the README is the second-highest signal you can produce, and it's entirely under your control. A 60-minute investment here is plausibly worth more than the entire codebase to a recruiter scanning your portfolio.
