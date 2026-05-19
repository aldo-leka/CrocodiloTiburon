# MVP roadmap

## Phase 1: Python CLI spike

- Resolve ticker to CIK.
- Search filings.
- Download latest 10-K.
- List documents in filing.
- Extract `item1a` and `item7`.
- Save a note locally.

## Phase 2: Local persistence

- SQLite schema via GRDB.
- Store companies, filings, documents, notes, and queue status.
- Cache raw SEC tars and parsed section text.

## Phase 3: macOS reader

- Company search.
- Filing list.
- Filing detail/document browser.
- Reader view with section rail.
- Notes panel.
- Original HTML view using `WKWebView`.

## Phase 4: Real research workflow

- A-to-Z research queue.
- Statuses: not started, in progress, interesting, pass, watchlist, candidate.
- Tags: risk, accounting, governance, dilution, debt, customer concentration, catalyst.
- Compare same section across years.
- Export notes to Markdown.

## Later

- AI assistant inside the reader.
- Embeddings/RAG over cached filings.
- Automated section diffs.
- Portfolio/watchlist alerts.
