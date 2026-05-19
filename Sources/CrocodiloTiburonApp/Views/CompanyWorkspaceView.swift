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
    }

    private var companyHeader: some View {
        VStack(alignment: .leading, spacing: CTTheme.Spacing.md) {
            Text(workspace.selectedCompany?.name ?? "No company selected")
                .font(CTTheme.Typography.displayMedium)
                .foregroundStyle(CTTheme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .fixedSize(horizontal: false, vertical: true)
            Text(workspace.selectedCompanyOverviewDescription)
                .font(CTTheme.Typography.body)
                .foregroundStyle(CTTheme.body)
                .lineLimit(6)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var filingsSection: some View {
        LazyVStack(spacing: 0) {
            FilingsToolbar()
            FilingsHeader()
            if !workspace.selectedCompanyFilings.isEmpty {
                ForEach(workspace.selectedCompanyFilings) { filing in
                    FilingRow(filing: filing, isSelected: filing.id == workspace.selectedFilingID) {
                        workspace.selectFiling(filing)
                    }
                    Hairline()
                }
            }
        }
        .background(CTTheme.surfaceSoft)
        .clipShape(RoundedRectangle(cornerRadius: CTTheme.Radius.lg, style: .continuous))
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
    }
}
