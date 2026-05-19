import SwiftUI

struct CompanyWorkspaceView: View {
    @EnvironmentObject private var workspace: WorkspaceStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar
            ScrollView {
                VStack(alignment: .leading, spacing: CTTheme.Spacing.lg) {
                    companyHeader
                    metricsGrid
                    filingsSection
                    documentsSection
                }
                .padding(CTTheme.Spacing.xl)
            }
        }
        .background(CTTheme.canvas)
    }

    private var topBar: some View {
        HStack {
            Text("Workspace")
                .font(CTTheme.Typography.label)
                .foregroundStyle(CTTheme.ink)
            Spacer()
            Button("Refresh filings") {}
                .buttonStyle(CTSecondaryButtonStyle())
            Button("Download latest 10-K") {}
                .buttonStyle(CTPrimaryButtonStyle())
        }
        .padding(.horizontal, CTTheme.Spacing.xl)
        .frame(height: 72)
        .background(CTTheme.canvas)
    }

    private var companyHeader: some View {
        VStack(alignment: .leading, spacing: CTTheme.Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: CTTheme.Spacing.xs) {
                    Text(workspace.selectedCompany?.name ?? "No company selected")
                        .font(CTTheme.Typography.displayMedium)
                        .foregroundStyle(CTTheme.ink)
                    Text(headerSubtitle)
                        .font(CTTheme.Typography.body)
                        .foregroundStyle(CTTheme.body)
                }
                Spacer()
                if let status = workspace.selectedCompany?.status.shortLabel {
                    PillTag(text: status, color: CTTheme.mint, textColor: CTTheme.forest)
                }
            }
            Text("Crocodilo should make SEC research feel like Airtable met a filing cabinet: structured, calm, fast, and not ugly.")
                .font(CTTheme.Typography.body)
                .foregroundStyle(CTTheme.body)
        }
    }

    private var headerSubtitle: String {
        guard let company = workspace.selectedCompany else { return "" }
        return "\(company.ticker) · \(company.exchange) · CIK \(company.cik) · \(company.industry)"
    }

    private var metricsGrid: some View {
        HStack(spacing: CTTheme.Spacing.md) {
            MetricCard(title: "Filings", value: "\(workspace.selectedCompanyFilings.count)", detail: "cached list")
            MetricCard(title: "Notes", value: "\(workspace.selectedNotes.count)", detail: "company + filing")
            MetricCard(title: "Documents", value: "\(workspace.documents.count)", detail: "selected filing")
        }
    }

    private var filingsSection: some View {
        VStack(alignment: .leading, spacing: CTTheme.Spacing.md) {
            SectionTitle(title: "Filings", subtitle: "Form, filing date, accession, cache status")
            VStack(spacing: 0) {
                FilingsHeader()
                ForEach(workspace.selectedCompanyFilings) { filing in
                    FilingRow(filing: filing, isSelected: filing.id == workspace.selectedFilingID) {
                        workspace.selectFiling(filing)
                    }
                    Hairline()
                }
            }
            .background(CTTheme.surfaceSoft)
            .clipShape(RoundedRectangle(cornerRadius: CTTheme.Radius.lg, style: .continuous))
        }
    }

    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: CTTheme.Spacing.md) {
            SectionTitle(title: "Documents in filing", subtitle: "SEC-style document list from metadata.json")
            VStack(spacing: 0) {
                ForEach(workspace.documents) { document in
                    DocumentRow(document: document, isSelected: document.id == workspace.selectedDocumentID) {
                        workspace.selectDocument(document)
                    }
                    Hairline()
                }
            }
            .background(CTTheme.canvas)
            .overlay(
                RoundedRectangle(cornerRadius: CTTheme.Radius.lg, style: .continuous)
                    .stroke(CTTheme.hairline, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: CTTheme.Radius.lg, style: .continuous))
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        CTCard(background: CTTheme.cream) {
            VStack(alignment: .leading, spacing: CTTheme.Spacing.xs) {
                Text(title)
                    .font(CTTheme.Typography.caption)
                    .foregroundStyle(CTTheme.muted)
                Text(value)
                    .font(.system(size: 34, weight: .regular))
                    .foregroundStyle(CTTheme.ink)
                Text(detail)
                    .font(CTTheme.Typography.body)
                    .foregroundStyle(CTTheme.body)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct SectionTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(CTTheme.Typography.titleSmall)
                .foregroundStyle(CTTheme.ink)
            Text(subtitle)
                .font(CTTheme.Typography.body)
                .foregroundStyle(CTTheme.muted)
        }
    }
}

private struct FilingsHeader: View {
    var body: some View {
        HStack {
            Text("Form").frame(width: 72, alignment: .leading)
            Text("Filing").frame(width: 104, alignment: .leading)
            Text("Title").frame(maxWidth: .infinity, alignment: .leading)
            Text("Status").frame(width: 120, alignment: .leading)
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
                    .frame(width: 72, alignment: .leading)
                Text(filing.filingDate.formatted(date: .abbreviated, time: .omitted))
                    .frame(width: 104, alignment: .leading)
                VStack(alignment: .leading, spacing: 4) {
                    Text(filing.title)
                        .foregroundStyle(CTTheme.ink)
                    Text(filing.accession)
                        .font(CTTheme.Typography.caption)
                        .foregroundStyle(CTTheme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 4) {
                    Text(filing.readStatus.rawValue)
                    Text(filing.isDownloaded ? "Downloaded" : "Not cached")
                        .font(CTTheme.Typography.caption)
                        .foregroundStyle(filing.isDownloaded ? CTTheme.success : CTTheme.muted)
                }
                .frame(width: 120, alignment: .leading)
            }
            .font(CTTheme.Typography.body)
            .foregroundStyle(CTTheme.body)
            .padding(CTTheme.Spacing.md)
            .background(isSelected ? CTTheme.cream : Color.clear)
        }
        .buttonStyle(.plain)
    }

    private var formColor: Color {
        switch filing.form {
        case "10-K": CTTheme.coral
        case "10-Q": CTTheme.link
        case "8-K": CTTheme.warning
        default: CTTheme.forest
        }
    }
}

private struct DocumentRow: View {
    let document: FilingDocument
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: CTTheme.Spacing.md) {
                Text("#\(document.sequence)")
                    .font(CTTheme.Typography.caption)
                    .foregroundStyle(CTTheme.muted)
                    .frame(width: 44, alignment: .leading)
                PillTag(text: document.type, color: document.isMainDocument ? CTTheme.coral.opacity(0.16) : CTTheme.surfaceStrong, textColor: document.isMainDocument ? CTTheme.coral : CTTheme.ink)
                    .frame(width: 92, alignment: .leading)
                VStack(alignment: .leading, spacing: 4) {
                    Text(document.description)
                        .font(CTTheme.Typography.body)
                        .foregroundStyle(CTTheme.ink)
                    Text(document.filename)
                        .font(CTTheme.Typography.caption)
                        .foregroundStyle(CTTheme.muted)
                }
                Spacer()
                Text(document.parseStatus.rawValue)
                    .font(CTTheme.Typography.caption)
                    .foregroundStyle(document.parseStatus == .parsed ? CTTheme.success : CTTheme.muted)
            }
            .padding(CTTheme.Spacing.md)
            .background(isSelected ? CTTheme.surfaceSoft : CTTheme.canvas)
        }
        .buttonStyle(.plain)
    }
}
