import SwiftUI
import DailyLedgerCore

struct AccountsView: View {
    @ObservedObject var model: AppModel
    @State private var selectedAccountID: UUID?
    @State private var editingAccount: LedgerAccount?
    @State private var showNewAccount = false
    @State private var showTransfer = false

    private var selectedAccount: LedgerAccount? {
        model.data.accounts.first { $0.id == selectedAccountID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("账户").font(.largeTitle.bold())
                    Text("总余额 \(Money.format(cents: model.totalBalance))").foregroundStyle(.secondary)
                }
                Spacer()
                Button("转账") { showTransfer = true }
                    .disabled(model.data.accounts.filter(\.isActive).count < 2)
                Button { showNewAccount = true } label: { Label("新增账户", systemImage: "plus") }
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 24).padding(.top, 22)

            HSplitView {
                List(model.data.accounts, selection: $selectedAccountID) { account in
                    HStack {
                        Image(systemName: account.isActive ? "wallet.bifold.fill" : "wallet.bifold")
                            .foregroundStyle(account.isActive ? .blue : .secondary)
                        VStack(alignment: .leading) {
                            Text(account.name)
                            if !account.isActive { Text("已停用").font(.caption).foregroundStyle(.secondary) }
                        }
                        Spacer()
                        AmountText(cents: model.balances[account.id] ?? account.openingBalanceCents)
                    }
                    .tag(account.id)
                }
                .frame(minWidth: 340)

                if let selectedAccount {
                    AccountDetailView(account: selectedAccount, model: model) { editingAccount = selectedAccount }
                        .frame(minWidth: 360)
                } else {
                    EmptyStateView(icon: "wallet.bifold", title: "选择一个账户", message: "查看余额和相关账目。")
                        .frame(minWidth: 360)
                }
            }
        }
        .sheet(isPresented: $showNewAccount) { AccountEditorView(model: model) }
        .sheet(item: $editingAccount) { AccountEditorView(model: model, existing: $0) }
        .sheet(isPresented: $showTransfer) { EntryEditorView(model: model, initialKind: .transfer) }
    }
}

private struct AccountDetailView: View {
    let account: LedgerAccount
    @ObservedObject var model: AppModel
    let edit: () -> Void

    private var entries: [LedgerEntry] {
        model.data.entries.filter { $0.accountID == account.id || $0.destinationAccountID == account.id }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(account.name).font(.title2.bold())
                    Text(account.isActive ? "使用中" : "已停用").foregroundStyle(.secondary)
                }
                Spacer()
                Button("编辑", action: edit)
            }
            AmountText(cents: model.balances[account.id] ?? account.openingBalanceCents).font(.largeTitle.bold())
            Text("初始余额 \(Money.format(cents: account.openingBalanceCents))")
                .font(.subheadline).foregroundStyle(.secondary)
            Divider()
            Text("最近账目").font(.headline)
            if entries.isEmpty {
                Text("暂无相关账目").foregroundStyle(.secondary)
            } else {
                List(entries.prefix(10)) { entry in
                    HStack {
                        Text(entry.note.isEmpty ? (entry.kind == .transfer ? "账户转账" : "账目") : entry.note)
                        Spacer()
                        AmountText(cents: entry.amountCents)
                    }
                }
                .listStyle(.inset)
            }
        }
        .padding(24)
    }
}

struct AccountEditorView: View {
    @ObservedObject var model: AppModel
    let existing: LedgerAccount?
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var openingBalance: String
    @State private var isActive: Bool

    init(model: AppModel, existing: LedgerAccount? = nil) {
        self.model = model
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        _openingBalance = State(initialValue: existing.map { String(format: "%.2f", Double($0.openingBalanceCents) / 100) } ?? "0")
        _isActive = State(initialValue: existing?.isActive ?? true)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(existing == nil ? "新增账户" : "编辑账户").font(.title2.bold())
            Form {
                TextField("账户名称", text: $name)
                TextField("初始余额", text: $openingBalance)
                if existing != nil { Toggle("账户启用", isOn: $isActive) }
            }
            HStack {
                Button("取消") { dismiss() }
                Spacer()
                Button("保存") { save() }.buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || Money.parseCents(openingBalance) == nil)
            }
        }
        .padding(24).frame(width: 430)
    }

    private func save() {
        guard let cents = Money.parseCents(openingBalance) else { return }
        let success: Bool
        if var existing {
            existing.name = name
            existing.openingBalanceCents = cents
            existing.isActive = isActive
            success = model.updateAccount(existing)
        } else {
            success = model.addAccount(name: name, openingBalanceCents: cents)
        }
        if success { dismiss() }
    }
}
