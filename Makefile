.PHONY: design bridge-resolve bridge-search ui-smoke ui-stress

design:
	npx getdesign@latest add airtable

bridge-resolve:
	python3 tools/datamule_bridge.py resolve AAPL

bridge-search:
	python3 tools/datamule_bridge.py search AAPL --forms 10-K 10-Q 8-K --start 2024-01-01 --end 2026-12-31

ui-smoke:
	swift build
	swift run CrocodiloTiburonUITestRunner --smoke --document-limit 12

ui-stress:
	swift build
	swift run CrocodiloTiburonUITestRunner --stress --ticker-limit 100 --document-limit 100
