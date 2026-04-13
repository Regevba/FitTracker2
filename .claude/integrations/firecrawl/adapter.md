# Firecrawl Web Scraping — Integration Adapter

## Service Info

- **Service:** Firecrawl Web Scraping & Extraction
- **Type:** MCP
- **MCP Server:** `firecrawl-mcp`
- **Auth:** `FIRECRAWL_API_KEY` (from Firecrawl account dashboard)
- **Consuming Skills:** /research, /marketing

## How to Call

1. Ensure `FIRECRAWL_API_KEY` env var is set.
2. Invoke tools as needed:
   - **Scrape a single page:** `firecrawl_scrape` with `url`, `formats: ["markdown", "extract"]`
   - **Crawl a site:** `firecrawl_crawl` with `url`, `maxDepth: 2`, `limit: 20`, `formats: ["markdown"]`
   - **Structured extraction:** `firecrawl_extract` with `urls: [...]`, `prompt` describing what to extract (e.g. "Extract app features, pricing, and user reviews")
   - **Search the web:** `firecrawl_search` with `query`, `limit: 10`, `scrapeOptions: { formats: ["markdown"] }`
3. Common use cases:
   - Competitor app landing pages: scrape App Store web listing URLs + product site
   - Market analysis: search for industry reports, benchmark posts
   - Feature comparison: structured extraction from competitor feature pages
4. Pass raw responses through `schema.json` for shape validation, then `mapping.json` for normalization.

## Data Flow

```
Firecrawl MCP (firecrawl-mcp) → scraped page content → schema.json (validate shape) → mapping.json (normalize fields) → shared layer
```

Writes to:
- `/Volumes/DevSSD/FitTracker2/.claude/shared/context.json` — competitive landscape, market analysis
- `/Volumes/DevSSD/FitTracker2/.claude/shared/feature-registry.json` — competitor feature comparisons

## Validation Gate

All data entering the shared layer passes through the automatic validation gate:

1. Adapter normalizes the response using `mapping.json`
2. Normalized data is cross-referenced against ALL existing shared layer state
3. Validation score = consistent fields / total comparable fields
4. Alert level determined:
   - **>= 95% GREEN:** Write to shared layer. Notify /research + /pm-workflow (info).
   - **90–95% ORANGE:** Write to shared layer. Notify /research + /pm-workflow (advisory).
   - **< 90% RED:** DO NOT write. Notify /research + /pm-workflow (alert). User must resolve.
5. Every ingestion logged to `/Volumes/DevSSD/FitTracker2/.claude/shared/change-log.json`

> Validation is automatic. Resolution is always manual — the user decides how to address RED or ORANGE alerts.

## Fallback

If the MCP is unavailable (API key expired, Firecrawl service down, rate limit hit):
- Skills continue operating with existing shared layer data
- No error thrown — graceful degradation
- Unavailability is logged to `change-log.json` with reason and timestamp for awareness

## Schema Notes

- `schema.json` defines the expected response shape after the MCP call
- `mapping.json` maps Firecrawl field names → shared layer field names
- If Firecrawl changes its response format, update `schema.json` and `mapping.json` here — no skill changes needed
- Web-scraped content is inherently unstructured; the extraction prompt is the primary quality control — review extracted data before relying on it for decisions
- All mapped fields carry `data_type: "measured"` — these are real scraped data, not estimates
