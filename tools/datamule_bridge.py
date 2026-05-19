#!/usr/bin/env python3
"""Small JSON CLI around datamule-python for Crocodilo Tiburon.

This is intentionally thin. The SwiftUI app should talk to our stable JSON shape,
not to datamule internals directly.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any

DEFAULT_USER_AGENT = "Aldo Leka CrocodiloTiburon/0.1 lekabros@gmail.com"
os.environ.setdefault("DATAMULE_SEC_USER_AGENT", DEFAULT_USER_AGENT)


def emit(payload: Any) -> None:
    print(json.dumps(payload, indent=2, default=str, ensure_ascii=False))


def fail(message: str, code: int = 1) -> None:
    emit({"ok": False, "error": message})
    raise SystemExit(code)


def import_datamule():
    try:
        from datamule import Index, Portfolio
        from datamule.utils.convenience import get_ciks_from_tickers
        return Index, Portfolio, get_ciks_from_tickers
    except Exception as exc:  # pragma: no cover - user setup boundary
        fail(
            "datamule is not installed or failed to import. Run: pip install -r requirements.txt. "
            f"Original error: {type(exc).__name__}: {exc}"
        )


def normalize_hit(hit: dict[str, Any]) -> dict[str, Any]:
    source = hit.get("_source", {})
    return {
        "id": hit.get("_id"),
        "score": hit.get("_score"),
        "accession": source.get("adsh") or (hit.get("_id", "").split(":")[0] if hit.get("_id") else None),
        "form": source.get("file_type") or source.get("form") or source.get("root_forms"),
        "root_forms": source.get("root_forms"),
        "filing_date": source.get("file_date"),
        "period_ending": source.get("period_ending"),
        "display_names": source.get("display_names"),
        "description": source.get("file_description"),
        "filename": (hit.get("_id", "").split(":", 1)[1] if ":" in hit.get("_id", "") else None),
        "ciks": source.get("ciks"),
    }


def cmd_resolve(args: argparse.Namespace) -> None:
    _, _, get_ciks_from_tickers = import_datamule()
    ciks = get_ciks_from_tickers(args.ticker.upper())
    emit({"ok": True, "ticker": args.ticker.upper(), "ciks": ciks})


def cmd_search(args: argparse.Namespace) -> None:
    Index, _, _ = import_datamule()
    index = Index()
    results = index.search_submissions(
        ticker=args.ticker.upper(),
        submission_type=args.forms if args.forms else None,
        filing_date=(args.start, args.end) if args.start and args.end else None,
        text_query=args.text,
        quiet=not args.verbose,
        requests_per_second=args.requests_per_second,
    )
    emit({
        "ok": True,
        "ticker": args.ticker.upper(),
        "count": len(results),
        "results": [normalize_hit(hit) for hit in results],
    })


def cmd_download(args: argparse.Namespace) -> None:
    _, Portfolio, _ = import_datamule()
    cache_dir = Path(args.cache_dir).expanduser().resolve()
    cache_dir.mkdir(parents=True, exist_ok=True)
    portfolio = Portfolio(str(cache_dir))
    portfolio.download_submissions(
        ticker=args.ticker.upper(),
        submission_type=args.forms if args.forms else None,
        filing_date=(args.start, args.end) if args.start and args.end else None,
        provider=args.provider,
        requests_per_second=args.requests_per_second,
        quiet=not args.verbose,
    )
    downloaded = sorted(str(path) for path in cache_dir.glob("*.tar"))
    emit({"ok": True, "cache_dir": str(cache_dir), "downloaded_tar_count": len(downloaded), "files": downloaded})


def submission_to_documents(submission: Any) -> list[dict[str, Any]]:
    metadata = getattr(submission, "metadata", None)
    content = getattr(metadata, "content", metadata)
    docs = []
    if isinstance(content, dict):
        docs = content.get("documents", []) or []
    normalized = []
    for doc in docs:
        normalized.append({
            "sequence": doc.get("sequence"),
            "type": doc.get("type"),
            "filename": doc.get("filename"),
            "description": doc.get("description"),
        })
    return normalized


def cmd_documents(args: argparse.Namespace) -> None:
    _, Portfolio, _ = import_datamule()
    portfolio = Portfolio(str(Path(args.cache_dir).expanduser().resolve()))
    matches = []
    for submission in portfolio:
        accession = getattr(submission, "accession", "")
        if args.accession.replace("-", "") in accession.replace("-", ""):
            matches.append({
                "accession": accession,
                "filing_date": getattr(submission, "filing_date", None),
                "documents": submission_to_documents(submission),
            })
    emit({"ok": True, "count": len(matches), "submissions": matches})


def cmd_section(args: argparse.Namespace) -> None:
    _, Portfolio, _ = import_datamule()
    portfolio = Portfolio(str(Path(args.cache_dir).expanduser().resolve()))
    for submission in portfolio:
        accession = getattr(submission, "accession", "")
        if args.accession.replace("-", "") not in accession.replace("-", ""):
            continue
        for document in submission.document_type(args.document_type):
            sections = document.get_section(title=args.section, format=args.format)
            emit({
                "ok": True,
                "accession": accession,
                "document_type": args.document_type,
                "section": args.section,
                "count": len(sections),
                "sections": sections,
            })
            return
    fail("No matching cached submission/document found", code=2)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Crocodilo Tiburon datamule bridge")
    sub = parser.add_subparsers(required=True)

    resolve = sub.add_parser("resolve", help="Resolve ticker to CIKs")
    resolve.add_argument("ticker")
    resolve.set_defaults(func=cmd_resolve)

    search = sub.add_parser("search", help="Search SEC filings")
    search.add_argument("ticker")
    search.add_argument("--forms", nargs="*", default=["10-K", "10-Q", "8-K", "DEF 14A"])
    search.add_argument("--start", default="2001-01-01")
    search.add_argument("--end", default="2026-12-31")
    search.add_argument("--text")
    search.add_argument("--requests-per-second", type=float, default=3.0)
    search.add_argument("--verbose", action="store_true")
    search.set_defaults(func=cmd_search)

    download = sub.add_parser("download", help="Download submissions to local cache")
    download.add_argument("ticker")
    download.add_argument("--forms", nargs="*", default=["10-K"])
    download.add_argument("--start", default="2024-01-01")
    download.add_argument("--end", default="2026-12-31")
    download.add_argument("--provider", default="sec")
    download.add_argument("--cache-dir", default="Data/SEC")
    download.add_argument("--requests-per-second", type=float, default=3.0)
    download.add_argument("--verbose", action="store_true")
    download.set_defaults(func=cmd_download)

    documents = sub.add_parser("documents", help="List documents in cached submission")
    documents.add_argument("accession")
    documents.add_argument("--cache-dir", default="Data/SEC")
    documents.set_defaults(func=cmd_documents)

    section = sub.add_parser("section", help="Extract section text from cached submission")
    section.add_argument("accession")
    section.add_argument("--document-type", default="10-K")
    section.add_argument("--section", default="item1a")
    section.add_argument("--format", default="text", choices=["text", "markdown", "dict"])
    section.add_argument("--cache-dir", default="Data/SEC")
    section.set_defaults(func=cmd_section)

    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
