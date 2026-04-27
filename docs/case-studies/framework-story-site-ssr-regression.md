# The Blank-Main Bug — Catching a Production SSR Regression After Promoting

**Date written:** 2026-04-20
<!-- doc-debt-backfill: fields added by scripts/backfill-case-study-fields.py -->

| Field | Value |
|---|---|
| Work Type | Enhancement |
| Dispatch Pattern | serial |

**Success Metrics:** TODO: review <!-- TODO: review -->

**Kill Criteria:** TODO: review <!-- TODO: review -->


> ⚙️ **Developer deep-dive.** Next.js 16 · `useSearchParams` · Suspense · static generation. PM/HR readers: this one's for the engineering side of the house — skip unless you want the code-level debug story.

> What does it look like when every page on a freshly-deployed site ships 251 characters of HTML? Here's the production incident nobody saw coming, because nobody looked past HTTP 200.

## Context

The fitme-story site was built in a single two-hour session using the superpowers brainstorming → writing-plans → subagent-driven-development chain. Preview passed. Tweaks landed. Production was promoted with `vercel --prod`. Every existing route returned HTTP 200 against both the preview and production URL. The site looked complete.

Then a routine `curl` against the production URL — not clicking through in a browser, just fetching the raw HTML — returned a page body of **251 characters**. Nav. Footer. Nothing else. Every `<main>` was empty.

## How the bug got caught

Browsers hide the symptom perfectly. JavaScript hydrates on page load, the missing content re-renders on the client, and the page looks fine to anyone who visits with JS enabled. Lighthouse scores looked clean (because Lighthouse runs a real browser). HTTP 200 was truthful — the request succeeded. A reviewer clicking the preview link would have seen a complete page.

What would NOT see a complete page: crawlers. Social-link preview fetchers. Screen readers before JS hydrates. Anything that runs the exact content-integrity audit this site was supposed to welcome — the independent-AI-audit story was a whole `/trust` page on the site itself.

The catch came from grepping the HTML content of routes that had just shipped, rather than trusting 200 OKs. One `curl | python -c "strip html, print first 2KB"` showed only the header and footer of the page. Not partial content — complete absence.

## Diagnosis

Root cause walked back to the root layout:

```tsx
<main className="flex-1">
  <Suspense fallback={null}>
    <PersonaProvider>{children}</PersonaProvider>
  </Suspense>
</main>
```

`PersonaProvider` called `usePersona()` internally, which called `useSearchParams()` synchronously at render time. In Next.js 16, `useSearchParams()` **suspends during static generation** because there's no request URL at build time. `Suspense` caught the suspension. `fallback={null}` rendered null for the entire children tree.

Every statically-pre-rendered page shipped with its entire body replaced by null. 40+ pages, all blank-main. In production.

## The first fix didn't work

Initial instinct: move the URL-param read into a `useEffect`. Don't synchronously read `searchParams` during render.

```tsx
const [persona, setPersonaState] = useState<Persona>(null);
useEffect(() => {
  const paramPersona = searchParams.get('p') as Persona;
  if (paramPersona) setPersonaState(paramPersona);
}, [searchParams]);
```

This looked right. `useState(null)` doesn't depend on URL. The effect runs only on the client. But the build still had blank pages.

**The thing that suspended wasn't `.get()`** — it was the `useSearchParams()` hook call itself. Calling the hook is what triggers the suspension, regardless of whether the return value is used at render time. Moving the consumption to `useEffect` doesn't help if the hook call itself is at the top of the component.

## The fix that worked

Split the persona hook into two layers:

- **`usePersonaState()`** — pure `useState` + `useEffect` + `localStorage`. No navigation hooks. Safe for SSG. Called by the Provider.
- **`PersonaSearchParamsSync`** — a new inner component that calls `useSearchParams()` and pushes resolved values into state. Returns `null` (it's side-effects-only). Wrapped in its own `<Suspense fallback={null}>` **inside** the Provider, scoping the suspension to this tiny inner component rather than the entire app.

```tsx
export function PersonaProvider({ children }: { children: React.ReactNode }) {
  const [persona, setPersona] = usePersonaState();
  return (
    <PersonaContext.Provider value={{ persona, setPersona }}>
      <Suspense fallback={null}>
        <PersonaSearchParamsSync setPersona={setPersona} />
      </Suspense>
      {children}
    </PersonaContext.Provider>
  );
}
```

Now the suspension-capable component is a null-returning child inside the Provider. The `children` tree renders fully server-side. On the client, `PersonaSearchParamsSync` hydrates and reads the URL, pushes any `?p=hr` into state, consumers re-render with the resolved persona.

Commit: `ab68987`. After the fix, `curl https://fitme-story.vercel.app` returned ~25KB of HTML with full hero, origin narrative, timeline, numbers, and CTA — all statically generated, all crawlable.

## Interesting decisions

1. **The outer Suspense isn't wrong — the fallback is.** You could argue "remove the Suspense entirely." But `useSearchParams` genuinely suspends during SSG. The framework expects a Suspense boundary somewhere. Removing it would move the bailout to the route segment level instead, producing dynamic rendering everywhere. Scoping the Suspense to a null-returning inner component is strictly better: static for all content, dynamic only for the URL-param read.

2. **`fallback={null}` vs `fallback={children}`.** An earlier draft tried `fallback={children}` — render the children without the provider during suspension, then swap in the provider once resolved. Works for SSR of the content, but double-renders everything, and any consumer that needs persona context sees `null` provider → default context during SSR. Cleaner to render the children only once, inside the Provider, with the Provider's own inner Suspense handling the URL-param sync.

3. **localStorage as the "real" persona source.** The Provider's `usePersonaState` writes to localStorage on every change. `PersonaSearchParamsSync` only promotes URL params into state, then writes localStorage. On subsequent visits, the URL is empty but localStorage has the last selection. Works naturally because the inner component's job is "sync URL into state if present" — it doesn't override anything.

## What the incident taught

**HTTP 200 is not content verification.** Every route returned 200. The site was trivially "healthy" by any uptime metric. The bug was invisible to everything except a curl-and-grep of the HTML. Adding `curl | grep "expected content"` to the post-deploy smoke checks would have caught this at preview-URL stage.

**Preview URLs have the same bug as production URLs.** The same build was shipped to both. If preview had been curl-grep-checked, the bug would have been caught before the `vercel --prod` push. Preview is production — they're the same build with a different domain alias.

**`useSearchParams` is an opt-out of static generation.** The React docs mention this, the Next.js docs mention this, but the implications for component composition aren't obvious until your whole app is blank. Any hook that suspends during SSG needs to be wrapped in its own Suspense boundary the moment it's used — not at the layout level, at the component level.

## Bottom line

One regex-sized oversight in the root layout erased the entire body of forty-some pre-rendered pages. It was invisible to browsers, invisible to HTTP health checks, invisible to Lighthouse. It was visible to `curl | grep`. That's the gap between "deployed" and "actually serving content," and it's not one the current auto-deploy pipeline can close on its own. The fix — a two-layer persona hook with a scoped inner Suspense — makes `useSearchParams` coexist with SSG properly, and the site now ships ~25KB of real HTML per route instead of 251 bytes of nav + footer.

**Time to catch:** ~5 minutes after the first curl. **Time to first-fix attempt:** ~10 minutes. **Time to working fix:** ~30 minutes (the first attempt didn't hold). **Time from deploy to detection:** was effectively "same session" — but could just as easily have been days of invisible blank-main pages if the author hadn't happened to curl the HTML.

## Artifacts

- Fix commit: `ab68987` (split the hook into SSG-safe state + inner-Suspense URL sync)
- Before: every page with 251-char `<main>` on production
- After: every page with ~25KB of pre-rendered HTML content
- Live: [fitme-story.vercel.app](https://fitme-story.vercel.app)
