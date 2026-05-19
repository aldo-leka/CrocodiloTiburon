#!/usr/bin/env python3
"""Small JSON CLI around datamule-python for Crocodilo Tiburon.

This is intentionally thin. The SwiftUI app should talk to our stable JSON shape,
not to datamule internals directly.
"""

from __future__ import annotations

import argparse
import contextlib
import ast
import io
import json
import os
import re
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


def capture_datamule(func):
    """Run noisy datamule calls without polluting JSON stdout."""
    stdout = io.StringIO()
    stderr = io.StringIO()
    with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
        result = func()
    logs = stdout.getvalue() + stderr.getvalue()
    if logs and os.environ.get("CROCODILO_BRIDGE_VERBOSE_LOGS") == "1":
        print(logs, file=sys.stderr, end="")
    return result


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


def search_datamule_submissions(args: argparse.Namespace) -> list[dict[str, Any]]:
    Index, _, get_ciks_from_tickers = import_datamule()
    filing_date = (args.start, args.end) if args.start and args.end else None
    submission_type = args.forms if args.forms else None

    if args.text:
        index = Index()
        return capture_datamule(
            lambda: index.search_submissions(
                ticker=args.ticker.upper(),
                submission_type=submission_type,
                filing_date=filing_date,
                text_query=args.text,
                quiet=not args.verbose,
                requests_per_second=args.requests_per_second,
            )
        )

    from datamule.sec.submissions.eftsquery import query_efts

    ciks = capture_datamule(lambda: get_ciks_from_tickers(args.ticker.upper()))
    if not ciks:
        fail(f"No CIKs found for ticker: {args.ticker.upper()}", code=2)

    return capture_datamule(
        lambda: query_efts(
            cik=ciks,
            submission_type=submission_type,
            filing_date=filing_date,
            requests_per_second=args.requests_per_second,
            quiet=not args.verbose,
        )
    )


def normalize_hit(hit: dict[str, Any]) -> dict[str, Any]:
    source = hit.get("_source", {})
    root_forms = source.get("root_forms")
    form = source.get("file_type") or source.get("form") or (root_forms[0] if isinstance(root_forms, list) and root_forms else None)
    return {
        "id": hit.get("_id"),
        "score": hit.get("_score"),
        "accession": source.get("adsh") or (hit.get("_id", "").split(":")[0] if hit.get("_id") else None),
        "form": form,
        "root_forms": root_forms,
        "filing_date": source.get("file_date"),
        "period_ending": source.get("period_ending"),
        "display_names": source.get("display_names"),
        "description": source.get("file_description"),
        "filename": (hit.get("_id", "").split(":", 1)[1] if ":" in hit.get("_id", "") else None),
        "ciks": source.get("ciks"),
        "items": source.get("items"),
        "file_number": source.get("file_num"),
        "film_number": source.get("film_num"),
        "business_locations": source.get("biz_locations"),
        "business_states": source.get("biz_states"),
        "incorporation_states": source.get("inc_states"),
        "sics": source.get("sics"),
        "sequence": source.get("sequence"),
        "xsl": source.get("xsl"),
    }


def cmd_resolve(args: argparse.Namespace) -> None:
    _, _, get_ciks_from_tickers = import_datamule()
    ciks = capture_datamule(lambda: get_ciks_from_tickers(args.ticker.upper()))
    emit({"ok": True, "ticker": args.ticker.upper(), "ciks": ciks})


def cmd_tickers(args: argparse.Namespace) -> None:
    from datamule import load_package_dataset

    rows = capture_datamule(lambda: list(load_package_dataset("listed_filer_metadata")))
    companies = []
    seen = set()

    for row in rows:
        try:
            tickers = ast.literal_eval(row.get("tickers", "[]"))
        except (SyntaxError, ValueError):
            tickers = []
        try:
            exchanges = [str(value) for value in ast.literal_eval(row.get("exchanges", "[]")) if value]
        except (SyntaxError, ValueError, TypeError):
            exchanges = []

        for ticker in tickers:
            ticker = str(ticker).strip().upper()
            if not ticker or ticker in seen:
                continue
            seen.add(ticker)
            companies.append({
                "ticker": ticker,
                "cik": row.get("cik"),
                "name": row.get("name"),
                "exchange": ", ".join(exchanges) if exchanges else None,
                "industry": row.get("sicDescription") or row.get("ownerOrg") or row.get("category"),
            })

    companies.sort(key=lambda item: item["ticker"])
    emit({"ok": True, "count": len(companies), "companies": companies[:args.limit] if args.limit else companies})


def cmd_profile(args: argparse.Namespace) -> None:
    try:
        import yfinance as yf
    except Exception as exc:  # pragma: no cover - user setup boundary
        fail(
            "yfinance is not installed or failed to import. Run: pip install -r requirements.txt. "
            f"Original error: {type(exc).__name__}: {exc}"
        )

    ticker = args.ticker.upper()

    def load_info() -> dict[str, Any]:
        handle = yf.Ticker(ticker)
        if hasattr(handle, "get_info"):
            return handle.get_info() or {}
        return handle.info or {}

    info = capture_datamule(load_info)
    summary = info.get("longBusinessSummary") or info.get("description")
    emit({
        "ok": True,
        "ticker": ticker,
        "long_name": info.get("longName"),
        "short_name": info.get("shortName"),
        "summary": summary,
        "sector": info.get("sector"),
        "industry": info.get("industry"),
        "website": info.get("website"),
    })


def cmd_search(args: argparse.Namespace) -> None:
    results = search_datamule_submissions(args)
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

    def download() -> None:
        portfolio = Portfolio(str(cache_dir))
        portfolio.download_submissions(
            ticker=args.ticker.upper(),
            submission_type=args.forms if args.forms else None,
            filing_date=(args.start, args.end) if args.start and args.end else None,
            provider=args.provider,
            requests_per_second=args.requests_per_second,
            quiet=not args.verbose,
        )

    capture_datamule(download)
    downloaded = sorted(str(path) for path in cache_dir.glob("*.tar"))
    emit({"ok": True, "cache_dir": str(cache_dir), "downloaded_tar_count": len(downloaded), "files": downloaded})


def submission_to_documents(submission: Any) -> list[dict[str, Any]]:
    docs = getattr(submission, "documents", []) or []
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
    portfolio = capture_datamule(lambda: Portfolio(str(Path(args.cache_dir).expanduser().resolve())))
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


def find_document(submission: Any, document_type: str | None, filename: str | None):
    if filename:
        for metadata in getattr(submission, "documents", []) or []:
            if metadata.get("filename") != filename:
                continue
            for document in submission.document_type(metadata.get("type")):
                if getattr(document, "filename", "") == filename:
                    return document
    if document_type:
        for document in submission.document_type(document_type):
            return document
    for metadata in getattr(submission, "documents", []) or []:
        for document in submission.document_type(metadata.get("type")):
            return document
    return None


def normalize_text(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, list):
        return "\n\n".join(normalize_text(item) for item in value if item is not None)
    text = str(value)
    return "" if text.strip() == "None" else text


def cmd_document(args: argparse.Namespace) -> None:
    _, Portfolio, _ = import_datamule()
    portfolio = capture_datamule(lambda: Portfolio(str(Path(args.cache_dir).expanduser().resolve())))
    for submission in portfolio:
        accession = getattr(submission, "accession", "")
        if args.accession.replace("-", "") not in accession.replace("-", ""):
            continue
        document = find_document(submission, args.document_type, args.filename)
        if document is None:
            fail("No matching cached document found", code=2)

        def load_payload() -> dict[str, Any]:
            content = getattr(document, "content", b"")
            if isinstance(content, bytes):
                html = content.decode("utf-8", errors="replace")
            elif content is None:
                html = ""
            else:
                html = str(content)

            payload = {
                "ok": True,
                "accession": accession,
                "document_type": getattr(document, "type", args.document_type),
                "filename": getattr(document, "filename", args.filename),
                "path": getattr(document, "path", None),
                "html": html,
            }
            if args.include_text:
                payload["text"] = normalize_text(getattr(document, "text", ""))
            if args.include_markdown:
                payload["markdown"] = normalize_text(getattr(document, "markdown", ""))
            return payload

        emit(capture_datamule(load_payload))
        return
    fail("No matching cached submission found", code=2)


def slug(value: Any) -> str:
    text = str(value or "").strip().lower()
    text = re.sub(r"[^a-z0-9]+", "-", text).strip("-")
    return text or "section"


def text_from_node(node: Any) -> str:
    if isinstance(node, dict):
        parts = []
        title = node.get("title")
        if title:
            parts.append(str(title))
        if "contents" in node:
            contents = node.get("contents")
            parts.append(text_from_node(contents))
        else:
            parts.extend(text_from_node(value) for value in node.values())
        return " ".join(part for part in parts if part)
    if isinstance(node, list):
        return " ".join(text_from_node(item) for item in node)
    if node is None:
        return ""
    return str(node)


def collect_sections_from_node(node: Any, output: list[dict[str, Any]]) -> None:
    if not isinstance(node, dict):
        return
    key = node.get("standardized_title")
    title = node.get("title")
    node_class = node.get("class")
    if key or node_class in {"item", "part", "signatures"}:
        lookup_key = key or title
        output.append({
            "lookup_key": lookup_key,
            "key": key or slug(title),
            "title": title or key,
            "class": node_class,
            "word_count": len(text_from_node(node).split()),
        })
    contents = node.get("contents")
    if isinstance(contents, dict):
        for child in contents.values():
            collect_sections_from_node(child, output)
    elif isinstance(contents, list):
        for child in contents:
            collect_sections_from_node(child, output)


def cmd_sections(args: argparse.Namespace) -> None:
    _, Portfolio, _ = import_datamule()
    portfolio = capture_datamule(lambda: Portfolio(str(Path(args.cache_dir).expanduser().resolve())))
    for submission in portfolio:
        accession = getattr(submission, "accession", "")
        if args.accession.replace("-", "") not in accession.replace("-", ""):
            continue
        document = find_document(submission, args.document_type, args.filename)
        if document is None:
            fail("No matching cached document found", code=2)

        def load_sections() -> list[dict[str, Any]]:
            data = getattr(document, "data", {})
            document_tree = data.get("document", {}) if isinstance(data, dict) else {}
            raw_sections: list[dict[str, Any]] = []
            if isinstance(document_tree, dict):
                for node in document_tree.values():
                    collect_sections_from_node(node, raw_sections)

            seen: dict[str, int] = {}
            sections = []
            for section in raw_sections:
                base_key = section.get("key")
                if not base_key:
                    continue
                seen[base_key] = seen.get(base_key, 0) + 1
                if seen[base_key] > 1:
                    section["key"] = f"{base_key}-{seen[base_key]}"
                sections.append(section)
            return sections

        sections = capture_datamule(load_sections)
        emit({"ok": True, "accession": accession, "count": len(sections), "sections": sections})
        return
    fail("No matching cached submission found", code=2)


def cmd_section(args: argparse.Namespace) -> None:
    _, Portfolio, _ = import_datamule()
    portfolio = capture_datamule(lambda: Portfolio(str(Path(args.cache_dir).expanduser().resolve())))
    for submission in portfolio:
        accession = getattr(submission, "accession", "")
        if args.accession.replace("-", "") not in accession.replace("-", ""):
            continue
        document = find_document(submission, args.document_type, args.filename)
        if document is not None:
            sections = capture_datamule(lambda: document.get_section(title=args.section, format=args.format))
            normalized_sections = [
                text for text in (normalize_text(section) for section in sections)
                if text.strip()
            ]
            emit({
                "ok": True,
                "accession": accession,
                "document_type": getattr(document, "type", args.document_type),
                "filename": getattr(document, "filename", args.filename),
                "section": args.section,
                "count": len(normalized_sections),
                "sections": normalized_sections,
            })
            return
    fail("No matching cached submission/document found", code=2)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Crocodilo Tiburon datamule bridge")
    sub = parser.add_subparsers(required=True)

    resolve = sub.add_parser("resolve", help="Resolve ticker to CIKs")
    resolve.add_argument("ticker")
    resolve.set_defaults(func=cmd_resolve)

    tickers = sub.add_parser("tickers", help="List datamule listed filer tickers")
    tickers.add_argument("--limit", type=int, default=0)
    tickers.set_defaults(func=cmd_tickers)

    profile = sub.add_parser("profile", help="Load company profile metadata from yfinance")
    profile.add_argument("ticker")
    profile.set_defaults(func=cmd_profile)

    search = sub.add_parser("search", help="Search SEC filings")
    search.add_argument("ticker")
    search.add_argument("--forms", nargs="*", default=None)
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

    document = sub.add_parser("document", help="Read a cached filing document")
    document.add_argument("accession")
    document.add_argument("--document-type")
    document.add_argument("--filename")
    document.add_argument("--cache-dir", default="Data/SEC")
    document.add_argument("--include-text", action="store_true")
    document.add_argument("--include-markdown", action="store_true")
    document.set_defaults(func=cmd_document)

    sections = sub.add_parser("sections", help="List parsed sections in a cached document")
    sections.add_argument("accession")
    sections.add_argument("--document-type")
    sections.add_argument("--filename")
    sections.add_argument("--cache-dir", default="Data/SEC")
    sections.set_defaults(func=cmd_sections)

    section = sub.add_parser("section", help="Extract section text from cached submission")
    section.add_argument("accession")
    section.add_argument("--document-type", default="10-K")
    section.add_argument("--filename")
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
