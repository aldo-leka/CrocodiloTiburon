import SwiftUI

struct CompanyWorkspaceView: View {
    @EnvironmentObject private var workspace: WorkspaceStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CTTheme.Spacing.xl) {
                companyHeader
                filingsSection
            }
            .padding(.horizontal, CTTheme.Spacing.xl)
            .padding(.top, CTTheme.Spacing.md)
            .padding(.bottom, CTTheme.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(CTTheme.canvas)
        .accessibilityIdentifier(CTAccessibility.companyWorkspaceScroll)
    }

    private var companyHeader: some View {
        VStack(alignment: .leading, spacing: CTTheme.Spacing.md) {
            Text(workspace.selectedCompany?.name ?? "No company selected")
                .font(CTTheme.Typography.displayMedium)
                .foregroundStyle(CTTheme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(CTAccessibility.companyHeaderTitle)
            Text(workspace.selectedCompanyOverviewDescription)
                .font(CTTheme.Typography.body)
                .foregroundStyle(CTTheme.body)
                .lineLimit(6)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var filingsSection: some View {
        let filings = workspace.selectedCompanyFilings

        VStack(spacing: 0) {
            if isUITesting {
                Text("Filing catalog")
                    .frame(width: 1, height: 1)
                    .opacity(0.01)
                    .accessibilityIdentifier(CTAccessibility.filingsCatalog)
                    .accessibilityValue(filingCatalogValue(for: filings))
            }

            LazyVStack(spacing: 0) {
                FilingsToolbar()
                FilingsHeader()
                if !filings.isEmpty {
                    ForEach(filings) { filing in
                        FilingRow(filing: filing, isSelected: filing.id == workspace.selectedFilingID) {
                            workspace.selectFiling(filing)
                        }
                        Hairline()
                    }
                }
            }
        }
        .background(CTTheme.surfaceSoft)
        .clipShape(RoundedRectangle(cornerRadius: CTTheme.Radius.lg, style: .continuous))
        .accessibilityIdentifier(CTAccessibility.filingsList)
    }

    private var isUITesting: Bool {
        ProcessInfo.processInfo.environment["CROCODILO_UI_TESTING"] == "1"
    }

    private func filingCatalogValue(for filings: [Filing]) -> String {
        guard isUITesting else { return "" }
        return filings.prefix(120)
            .map { filing in
                "\(filing.accession)|\(filing.id.uuidString.lowercased())|\(filing.companyID.uuidString.lowercased())"
            }
            .joined(separator: "\n")
    }
}

private struct FilingsToolbar: View {
    @EnvironmentObject private var workspace: WorkspaceStore

    var body: some View {
        HStack {
            Spacer()
            Toggle("Exclude Ownership", isOn: Binding(
                get: { workspace.excludeOwnershipReports },
                set: { workspace.setExcludeOwnershipReports($0) }
            ))
            .toggleStyle(.switch)
            .font(CTTheme.Typography.caption)
            .foregroundStyle(CTTheme.muted)
            .accessibilityIdentifier(CTAccessibility.filingsOwnershipToggle)
        }
        .padding(.horizontal, CTTheme.Spacing.md)
        .padding(.vertical, CTTheme.Spacing.sm)
    }
}

private struct FilingsHeader: View {
    var body: some View {
        HStack {
            Text("Form").frame(width: 74, alignment: .leading)
            Text("Filer").frame(maxWidth: .infinity, alignment: .leading)
            Text("Filed").frame(width: 96, alignment: .trailing)
        }
        .font(CTTheme.Typography.caption)
        .foregroundStyle(CTTheme.muted)
        .padding(.horizontal, CTTheme.Spacing.md)
        .padding(.vertical, CTTheme.Spacing.sm)
    }
}

private struct FilingRow: View {
    let filing: Filing
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: CTTheme.Spacing.md) {
                Text(filing.form)
                    .lineLimit(1)
                    .frame(width: 74, alignment: .leading)
                Text(filing.filer ?? "")
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(filing.filingDate.formatted(date: .abbreviated, time: .omitted))
                    .lineLimit(1)
                    .frame(width: 96, alignment: .trailing)
            }
            .font(CTTheme.Typography.body)
            .foregroundStyle(CTTheme.body)
            .padding(CTTheme.Spacing.md)
            .frame(minHeight: 56)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? CTTheme.cream : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(CTAccessibility.filingRow(accession: filing.accession))
        .accessibilityLabel("\(filing.form) \(filing.filer ?? "")")
        .accessibilityValue(
            "\(filing.accession)|\(filing.id.uuidString.lowercased())|\(filing.companyID.uuidString.lowercased())"
        )
    }
}
