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
        VStack(spacing: 0) {
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

private struct FilingsHeader: View {
    var body: some View {
        HStack {
            Text("Form").frame(width: 82, alignment: .leading)
            Text("Filing").frame(maxWidth: .infinity, alignment: .trailing)
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
                PillTag(text: filing.form, color: formColor.opacity(0.16), textColor: formColor)
                    .frame(width: 82, alignment: .leading)
                Text(filing.filingDate.formatted(date: .abbreviated, time: .omitted))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
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

    private var formColor: Color {
        switch filing.form {
        case "10-K": CTTheme.coral
        case "10-Q": CTTheme.link
        case "8-K": CTTheme.warning
        case "20-F": CTTheme.forest
        case "6-K": CTTheme.link
        case "40-F": CTTheme.coral
        default: CTTheme.forest
        }
    }
}
