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
                .accessibilityIdentifier(CTAccessibility.sidebarSearchField)
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

    @ViewBuilder
    private var companyList: some View {
        let openedCompanyIDs = workspace.openedCompanyIDs

        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: CTTheme.Spacing.xs, pinnedViews: [.sectionHeaders]) {
                    ForEach(groupedCompanies) { group in
                        Section {
                            ForEach(group.companies) { company in
                                CompanyRow(
                                    company: company,
                                    isSelected: workspace.selectedCompanyID == company.id,
                                    isDirty: openedCompanyIDs.contains(company.id)
                                ) {
                                    workspace.selectCompany(company)
                                }
                                .id(company.id)
                            }
                        } header: {
                            CompanyLetterHeader(letter: group.letter)
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier(CTAccessibility.sidebarCompanyList)
            .onAppear {
                scrollToPreferredCompany(with: proxy)
            }
            .onChange(of: workspace.selectedCompanyID) { _, _ in
                scrollToPreferredCompany(with: proxy)
            }
            .onChange(of: workspace.query) { _, _ in
                scrollToPreferredCompany(with: proxy)
            }
            .onChange(of: workspace.filteredCompanies.count) { _, _ in
                scrollToPreferredCompany(with: proxy)
            }
        }
    }

    private var groupedCompanies: [CompanyLetterGroup] {
        let groups = Dictionary(grouping: workspace.filteredCompanies) { company in
            let first = company.ticker.first.map(String.init)?.uppercased() ?? "#"
            return first.range(of: #"^[A-Z]$"#, options: .regularExpression) == nil ? "#" : first
        }

        return groups.keys.sorted { lhs, rhs in
            if lhs == "#" { return false }
            if rhs == "#" { return true }
            return lhs < rhs
        }
        .map { letter in
            CompanyLetterGroup(letter: letter, companies: groups[letter] ?? [])
        }
    }

    private func scrollToPreferredCompany(with proxy: ScrollViewProxy) {
        guard let targetID = preferredScrollCompanyID() else { return }
        let anchor: UnitPoint = workspace.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .center : .top

        Task { @MainActor in
            withAnimation(.easeInOut(duration: 0.2)) {
                proxy.scrollTo(targetID, anchor: anchor)
            }
        }
    }

    private func preferredScrollCompanyID() -> Company.ID? {
        let searchQuery = workspace.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchQuery.isEmpty else {
            return workspace.selectedCompanyID
        }

        let exactMatch = workspace.filteredCompanies.first { company in
            company.ticker.compare(searchQuery, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame ||
            company.cik.compare(searchQuery, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }

        return exactMatch?.id ?? workspace.filteredCompanies.first?.id
    }

    private func focusSearchField() {
        activateAppWindow()
        Task { @MainActor in
            searchFocused = true
        }
    }
}

private struct CompanyLetterGroup: Identifiable {
    var id: String { letter }
    let letter: String
    let companies: [Company]
}

private struct CompanyLetterHeader: View {
    let letter: String

    var body: some View {
        HStack(spacing: CTTheme.Spacing.sm) {
            Text(letter)
                .font(CTTheme.Typography.caption)
                .foregroundStyle(CTTheme.muted)
                .frame(width: 18, alignment: .leading)
            Hairline()
        }
        .padding(.top, CTTheme.Spacing.sm)
        .padding(.bottom, CTTheme.Spacing.xs)
        .background(CTTheme.surfaceSoft)
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
        .accessibilityIdentifier(CTAccessibility.companyRow(ticker: company.ticker))
        .accessibilityLabel("\(company.ticker) \(company.name)")
        .accessibilityValue("\(company.ticker)|\(company.id.uuidString.lowercased())")
    }

    private var rowBackground: Color {
        if isSelected { return CTTheme.canvas }
        return Color.clear
    }
}
