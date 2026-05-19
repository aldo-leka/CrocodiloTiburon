.PHONY: design bridge-resolve bridge-search

design:
	npx getdesign@latest add airtable

bridge-resolve:
	python3 tools/datamule_bridge.py resolve AAPL

bridge-search:
	python3 tools/datamule_bridge.py search AAPL --forms 10-K 10-Q 8-K --start 2024-01-01 --end 2026-12-31
