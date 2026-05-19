# Design implementation notes

The root `DESIGN.md` file was generated with:

```bash
npx getdesign@latest add airtable
```

Crocodilo Tiburon maps that Airtable-inspired system into a native macOS research workspace:

- White canvas and near-black ink as the base.
- No SaaS-gradient hero noise.
- Coral/forest/dark signature cards for high-voltage moments.
- Cream cards for calm research callouts.
- Hairline borders and flat surfaces instead of heavy shadows.
- Modest type weights, using Apple system fonts as the Haas substitute.
- Three-pane productivity layout: queue, workspace, reader/notes.

Current SwiftUI design files:

- `Design/DesignTokens.swift`
- `Design/Components.swift`
- `Views/SidebarView.swift`
- `Views/CompanyWorkspaceView.swift`
- `Views/ReaderWorkspaceView.swift`

Important product-design principle:

The app should feel like a calm filing research desk, not a generic AI dashboard. The user should be able to read for an hour without visual fatigue.
