# Architecture

## Product shape

Crocodilo Tiburon is a local-first macOS research desk:

```text
SwiftUI app
  ↓ stable JSON/process boundary
Python datamule bridge
  ↓
datamule-python + SEC APIs
  ↓
Local cache: tar submissions + SQLite metadata/notes
```

## Native app

- SwiftUI for the application shell.
- AppKit escape hatches where SwiftUI is weak.
- `WKWebView` for original HTML filing rendering.
- `PDFKit` for PDFs and PDF exhibits.
- GRDB/SQLite for local persistence.

## Data model

Core tables to implement next:

- `companies`
- `filings`
- `filing_documents`
- `notes`
- `research_queue`
- optional `document_sections`
- optional FTS index later

## Bridge contract

The SwiftUI app should call `tools/datamule_bridge.py` or a local API that emits stable JSON:

- `resolve TICKER`
- `search TICKER --forms 10-K 10-Q 8-K --start YYYY-MM-DD --end YYYY-MM-DD`
- `download TICKER --forms 10-K --start YYYY-MM-DD --end YYYY-MM-DD`
- `documents ACCESSION`
- `section ACCESSION --document-type 10-K --section item1a`

This gives us a cheap backend now while preserving the option to replace datamule or write a native service later.

## Caching rules

- Ticker/CIK metadata should be cached.
- Filing lists should be cached per company.
- Downloaded SEC submissions should be stored as `.tar` files and reused forever unless manually deleted.
- Parsed sections should be cached after first parse.
- The app should be useful offline for cached filings and notes.
