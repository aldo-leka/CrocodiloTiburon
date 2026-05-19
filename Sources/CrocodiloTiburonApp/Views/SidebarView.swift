import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var workspace: WorkspaceStore
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: CTTheme.Spacing.lg) {
            header
            searchField
            heroCard
            queueHeader
            companyList
            Spacer(minLength: CTTheme.Spacing.md)
            footerActions
        }
        .padding(CTTheme.Spacing.lg)
        .background(CTTheme.surfaceSoft)
        .onChange(of: workspace.shouldFocusSearch) { _, shouldFocus in
            if shouldFocus {
                searchFocused = true
                workspace.shouldFocusSearch = false
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: CTTheme.Spacing.xs) {
            HStack(spacing: CTTheme.Spacing.sm) {
                Text("🐊")
                    .font(.system(size: 28))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Crocodilo Tiburon")
                        .font(CTTheme.Typography.titleSmall)
                        .foregroundStyle(CTTheme.ink)
                    Text("SEC research desk")
                        .font(CTTheme.Typography.body)
                        .foregroundStyle(CTTheme.muted)
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: CTTheme.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(CTTheme.muted)
            TextField("Ticker, CIK, or company", text: $workspace.query)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .font(CTTheme.Typography.body)
        }
        .padding(.horizontal, CTTheme.Spacing.md)
        .frame(height: 44)
        .background(CTTheme.canvas)
        .overlay(
            RoundedRectangle(cornerRadius: CTTheme.Radius.sm, style: .continuous)
                .stroke(searchFocused ? CTTheme.link : CTTheme.hairline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: CTTheme.Radius.sm, style: .continuous))
    }

    private var heroCard: some View {
        CTCard(background: CTTheme.coral) {
            VStack(alignment: .leading, spacing: CTTheme.Spacing.md) {
                Text("Read filings like a private investor, not like a browser tab hoarder.")
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Ticker → filings → sections → notes.")
                    .font(CTTheme.Typography.body)
                    .foregroundStyle(.white.opacity(0.82))
                Button("Sync SEC") {}
                    .buttonStyle(CTSecondaryButtonStyle())
            }
        }
    }

    private var queueHeader: some View {
        HStack {
            Text("Research queue")
                .font(CTTheme.Typography.label)
                .foregroundStyle(CTTheme.ink)
            Spacer()
            PillTag(text: "A-Z", color: CTTheme.cream)
        }
    }

    private var companyList: some View {
        ScrollView {
            LazyVStack(spacing: CTTheme.Spacing.xs) {
                ForEach(workspace.filteredCompanies) { company in
                    CompanyRow(company: company, isSelected: workspace.selectedCompanyID == company.id) {
                        workspace.selectCompany(company)
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var footerActions: some View {
        VStack(spacing: CTTheme.Spacing.sm) {
            Button("Add company") {}
                .buttonStyle(CTPrimaryButtonStyle())
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Backend bridge: datamule-python via tools/datamule_bridge.py")
                .font(CTTheme.Typography.body)
                .foregroundStyle(CTTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct CompanyRow: View {
    let company: Company
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: CTTheme.Spacing.sm) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(company.ticker)
                            .font(CTTheme.Typography.label)
                            .foregroundStyle(CTTheme.ink)
                        PillTag(text: company.status.shortLabel, color: statusColor.opacity(0.18), textColor: statusColor)
                    }
                    Text(company.name)
                        .font(CTTheme.Typography.body)
                        .foregroundStyle(CTTheme.body)
                        .lineLimit(1)
                    Text("CIK \(company.cik) · \(company.industry)")
                        .font(CTTheme.Typography.caption)
                        .foregroundStyle(CTTheme.muted)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(CTTheme.Spacing.md)
            .background(isSelected ? CTTheme.canvas : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: CTTheme.Radius.md, style: .continuous)
                    .stroke(isSelected ? CTTheme.hairline : Color.clear, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: CTTheme.Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var statusColor: Color {
        switch company.status {
        case .candidate: CTTheme.coral
        case .watchlist, .interesting: CTTheme.forest
        case .pass: CTTheme.muted
        case .inProgress, .readAnnual: CTTheme.link
        case .notStarted: CTTheme.muted
        }
    }
}
