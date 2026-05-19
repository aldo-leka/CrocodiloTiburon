# Crocodilo Tiburon

A native macOS SEC filings research desk for serious investors: search a ticker, browse SEC filings, read clean 10-K/10-Q/8-K/proxy documents, and keep structured notes by company, filing, document, and section.

The first backend wedge is [`datamule-python`](https://github.com/john-friedman/datamule-python), which already handles ticker/CIK lookup, SEC filing search, submission downloads, filing document metadata, and parsing common SEC documents into text/markdown/sections.

## Direction

- **Native app:** SwiftUI macOS first, AppKit escape hatches where needed.
- **Original filing rendering:** `WKWebView`.
- **PDF/exhibits:** `PDFKit`.
- **Local persistence:** SQLite via GRDB.
- **SEC plumbing:** Python datamule bridge first, later replace only if needed.
- **Design reference:** `DESIGN.md`, generated from `npx getdesign@latest add airtable`.

## Current status

This repo now contains:

- A Swift Package app skeleton that opens directly in Xcode.
- Airtable-inspired design tokens/components in SwiftUI.
- A three-pane research workspace prototype with sample SEC filing data.
- A Python `tools/datamule_bridge.py` CLI scaffold for live SEC/data plumbing.
- Architecture, roadmap, and datamule feasibility notes.

## Run the app on macOS

Open the package in Xcode:

```bash
open Package.swift
```

Then choose the `CrocodiloTiburon` executable target and run.

This Linux environment cannot build SwiftUI/macOS apps, so final compile verification needs Xcode on macOS.

## Try the datamule bridge

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
export DATAMULE_SEC_USER_AGENT="Aldo Leka CrocodiloTiburon/0.1 lekabros@gmail.com"
python tools/datamule_bridge.py resolve AAPL
python tools/datamule_bridge.py search AAPL --forms 10-K 10-Q 8-K --start 2024-01-01 --end 2026-12-31
```

## Repo map

```text
Sources/CrocodiloTiburonApp/
  App/          App entry point and workspace state
  Design/       Airtable-inspired SwiftUI tokens and components
  Models/       Company, filing, document, note models
  Services/     Datamule bridge and local SQLite/GRDB services
  Views/        Sidebar, filing list, reader, notes UI

tools/
  datamule_bridge.py

docs/
  datamule-findings.md
  architecture.md
  mvp-roadmap.md
  design-implementation.md
```
