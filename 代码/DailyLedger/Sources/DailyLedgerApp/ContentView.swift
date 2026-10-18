import SwiftUI
import DailyLedgerCore

struct ContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        NavigationSplitView {
            List(AppModel.Page.allCases, selection: $model.selection) { page in
                Label(page.rawValue, systemImage: page.icon)
                    .tag(page)
            }
            .navigationTitle("日常记账")
            .navigationSplitViewColumnWidth(min: 180, ideal: 210)
        } detail: {
            Group {
                switch model.selection {
                case .overview: OverviewView(model: model)
                case .entries: LedgerListView(model: model)
                case .accounts: AccountsView(model: model)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    Button { model.moveMonth(-1) } label: { Image(systemName: "chevron.left") }
                    Text(model.selectedMonth.displayName)
                        .font(.headline)
                        .frame(minWidth: 96)
                    Button { model.moveMonth(1) } label: { Image(systemName: "chevron.right") }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { model.showNewEntry = true } label: {
                        Label("新增记录", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.data.accounts.filter(\.isActive).isEmpty || model.isReadOnly)
                }
            }
        }
        .sheet(isPresented: $model.showNewEntry) {
            EntryEditorView(model: model)
        }
        .sheet(isPresented: $model.showOnboarding) {
            OnboardingView(model: model)
                .interactiveDismissDisabled(model.data.accounts.isEmpty)
        }
        .alert("无法完成操作", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("好") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "未知错误")
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        ContentUnavailableView(title, systemImage: icon, description: Text(message))
    }
}

struct AmountText: View {
    let cents: Int64
    var color: Color = .primary

    var body: some View {
        Text(Money.format(cents: cents))
            .monospacedDigit()
            .foregroundStyle(color)
    }
}
