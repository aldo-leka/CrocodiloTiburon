# Datamule feasibility findings

Checked on 2026-05-19 against `john-friedman/datamule-python` commit `4008773`.

## Verdict

Use `datamule-python` for the MVP backend. It is good enough for a personal macOS SEC filings research tool.

It supports:

- Ticker to CIK lookup.
- SEC filing search/listing by ticker/CIK/form/date/text.
- Downloading SEC submissions.
- Preserving SEC-style filing document metadata.
- Parsing common HTML/XML filings to text, markdown, nested data, tables, and standardized sections.

## Live tests performed

- `get_ciks_from_tickers("AAPL")` returned `[320193]`.
- Searching Apple from 2025-01-01 to 2026-05-19 returned 122 filing/document hits.
- Observed form types included 10-K, 10-Q, 8-K, DEF 14A, DEFA14A, S-8, 424B2, 144, 4, 3, 13G variants, and others.
- Downloaded Apple 2024 and 2025 10-K submissions.
- Apple 2025 10-K tar contained 90 document items.
- Apple 2024 10-K tar contained 102 document items.
- Main 10-K parsed successfully:
  - `Document.text` worked.
  - `Document.markdown` produced about 283k characters for Apple 2025 10-K.
  - `get_section(title="item1a", format="text")` worked.
  - `get_section(title="item7", format="text")` worked.
  - `get_section(title="signatures", format="text")` worked.

## Useful APIs

```python
from datamule import Portfolio, Index
from datamule.utils.convenience import get_ciks_from_tickers

get_ciks_from_tickers("AAPL")

index = Index()
results = index.search_submissions(
    ticker="AAPL",
    submission_type="10-K",
    filing_date=("2024-01-01", "2025-12-31"),
)

portfolio = Portfolio("Data/SEC")
portfolio.download_submissions(
    ticker="AAPL",
    submission_type="10-K",
    filing_date=("2024-01-01", "2025-12-31"),
    provider="sec",
    requests_per_second=3,
)

for submission in portfolio:
    print(submission.accession, submission.filing_date)
    for document in submission:
        print(document.type, document.filename, document.description)

for document in submission.document_type("10-K"):
    print(document.get_section(title="item1a", format="text"))
```

## Limitations

- Direct accession download is awkward through the high-level SEC provider path. Work around this with ticker/form/date downloads, lower-level streaming, or a custom selected-accession downloader.
- Parsing quality varies for old/bizarre filings and PDFs.
- Section extraction uses standardized keys such as `item1a`, not literal headings like `Item 1A`.
- SEC rate limits matter. Use a real `DATAMULE_SEC_USER_AGENT` and cache aggressively.
- Wrap datamule behind our own JSON service layer. Do not couple UI directly to datamule internals.
