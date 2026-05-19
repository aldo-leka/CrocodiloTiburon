import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var workspace: WorkspaceStore
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: CTTheme.Spacing.md) {
            header
            searchField
            companyList
        }
        .padding(CTTheme.Spacing.lg)
        .background(CTTheme.surfaceSoft)
        .onAppear {
            searchText = workspace.query
        }
        .onChange(of: searchText) { _, value in
            workspace.query = value
        }
        .onChange(of: workspace.shouldFocusSearch) { _, shouldFocus in
            if shouldFocus {
                focusSearchField()
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
            TextField("Ticker, CIK, or company", text: $searchText)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .font(CTTheme.Typography.body)
                .foregroundStyle(CTTheme.ink)
        }
        .padding(.horizontal, CTTheme.Spacing.md)
        .frame(height: 44)
        .background(CTTheme.canvas)
        .overlay(
            RoundedRectangle(cornerRadius: CTTheme.Radius.sm, style: .continuous)
                .stroke(searchFocused ? CTTheme.link : CTTheme.hairline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: CTTheme.Radius.sm, style: .continuous))
        .simultaneousGesture(
            TapGesture().onEnded {
                focusSearchField()
            }
        )
    }

    private var companyList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: CTTheme.Spacing.xs) {
                    ForEach(workspace.filteredCompanies) { company in
                        CompanyRow(
                            company: company,
                            isSelected: workspace.selectedCompanyID == company.id,
                            isDirty: workspace.companyHasOpenedFiling(company)
                        ) {
                            workspace.selectCompany(company)
                        }
                        .id(company.id)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .onAppear {
                scrollToSelected(with: proxy)
            }
            .onChange(of: workspace.selectedCompanyID) { _, _ in
                scrollToSelected(with: proxy)
            }
            .onChange(of: workspace.filteredCompanies.count) { _, _ in
                scrollToSelected(with: proxy)
            }
        }
    }

    private func scrollToSelected(with proxy: ScrollViewProxy) {
        guard let selectedCompanyID = workspace.selectedCompanyID else { return }
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.2)) {
                proxy.scrollTo(selectedCompanyID, anchor: .center)
            }
        }
    }

    private func focusSearchField() {
        activateAppWindow()
        DispatchQueue.main.async {
            searchFocused = true
        }
    }
}

private struct CompanyRow: View {
    let company: Company
    let isSelected: Bool
    let isDirty: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: CTTheme.Spacing.sm) {
                Circle()
                    .fill(isDirty ? CTTheme.coral : CTTheme.surfaceStrong)
                    .frame(width: 8, height: 8)
                HStack(spacing: CTTheme.Spacing.xs) {
                    Text(company.ticker)
                        .font(CTTheme.Typography.label)
                        .foregroundStyle(CTTheme.ink)
                        .lineLimit(1)
                    Text(company.name)
                        .font(CTTheme.Typography.body)
                        .foregroundStyle(CTTheme.body)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, CTTheme.Spacing.md)
            .padding(.vertical, CTTheme.Spacing.sm)
            .background(rowBackground)
            .contentShape(RoundedRectangle(cornerRadius: CTTheme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CTTheme.Radius.md, style: .continuous)
                    .stroke(isSelected ? CTTheme.link : Color.clear, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: CTTheme.Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var rowBackground: Color {
        if isSelected { return CTTheme.canvas }
        if isDirty { return CTTheme.cream.opacity(0.4) }
        return Color.clear
    }
}
