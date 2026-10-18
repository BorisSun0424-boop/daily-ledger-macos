import SwiftUI
import DailyLedgerCore

struct EntryEditorView: View {
    @ObservedObject var model: AppModel
    let existing: LedgerEntry?
    @Environment(\.dismiss) private var dismiss

    @State private var kind: EntryKind
    @State private var amountText: String
    @State private var categoryID: UUID?
    @State private var accountID: UUID?
    @State private var destinationAccountID: UUID?
    @State private var date: Date
    @State private var note: String

    init(model: AppModel, existing: LedgerEntry? = nil, initialKind: EntryKind = .expense) {
        self.model = model
        self.existing = existing
        _kind = State(initialValue: existing?.kind ?? initialKind)
        _amountText = State(initialValue: existing.map { String(format: "%.2f", Double($0.amountCents) / 100) } ?? "")
        _categoryID = State(initialValue: existing?.categoryID)
        _accountID = State(initialValue: existing?.accountID)
        _destinationAccountID = State(initialValue: existing?.destinationAccountID)
        _date = State(initialValue: existing?.date ?? Date())
        _note = State(initialValue: existing?.note ?? "")
    }

    private var availableCategories: [LedgerCategory] {
        guard kind != .transfer else { return [] }
        let categoryKind: CategoryKind = kind == .expense ? .expense : .income
        return model.data.categories.filter { $0.kind == categoryKind }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var activeAccounts: [LedgerAccount] { model.data.accounts.filter(\.isActive) }
    private var amountCents: Int64? { Money.parseCents(amountText) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(existing == nil ? "新增记录" : "编辑记录").font(.title2.bold())
                Spacer()
            }.padding(22)

            Form {
                Picker("类型", selection: $kind) {
                    Text("支出").tag(EntryKind.expense)
                    Text("收入").tag(EntryKind.income)
                    Text("转账").tag(EntryKind.transfer)
                }
                .pickerStyle(.segmented)
                .onChange(of: kind) { _, _ in categoryID = availableCategories.first?.id }

                TextField("金额", text: $amountText, prompt: Text("0.00"))
                    .font(.title3.monospacedDigit())

                if kind != .transfer {
                    Picker("分类", selection: $categoryID) {
                        ForEach(availableCategories) { category in
                            Text(category.name).tag(Optional(category.id))
                        }
                    }
                }

                Picker(kind == .transfer ? "转出账户" : "账户", selection: $accountID) {
                    ForEach(activeAccounts) { account in
                        Text(account.name).tag(Optional(account.id))
                    }
                }

                if kind == .transfer {
                    Picker("转入账户", selection: $destinationAccountID) {
                        ForEach(activeAccounts.filter { $0.id != accountID }) { account in
                            Text(account.name).tag(Optional(account.id))
                        }
                    }
                }

                DatePicker("日期", selection: $date, displayedComponents: .date)
                TextField("备注（选填）", text: $note)
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Button("取消", role: .cancel) { dismiss() }
                Spacer()
                Button("保存") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
            }
            .padding(18)
        }
        .frame(width: 470, height: 510)
        .onAppear { installDefaults() }
    }

    private var canSave: Bool {
        guard let amountCents, amountCents > 0, accountID != nil else { return false }
        if kind == .transfer { return destinationAccountID != nil && destinationAccountID != accountID }
        return categoryID != nil
    }

    private func installDefaults() {
        if accountID == nil { accountID = activeAccounts.first?.id }
        if categoryID == nil { categoryID = availableCategories.first?.id }
        if kind == .transfer && destinationAccountID == nil {
            destinationAccountID = activeAccounts.first { $0.id != accountID }?.id
        }
    }

    private func save() {
        guard let amountCents, let accountID else { return }
        let entry = LedgerEntry(
            id: existing?.id ?? UUID(),
            kind: kind,
            amountCents: amountCents,
            categoryID: kind == .transfer ? nil : categoryID,
            accountID: accountID,
            destinationAccountID: kind == .transfer ? destinationAccountID : nil,
            date: date,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        if model.saveEntry(entry, isEditing: existing != nil) { dismiss() }
    }
}

struct BudgetEditorView: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var amountText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("\(model.selectedMonth.displayName)预算").font(.title2.bold())
            TextField("预算金额", text: $amountText, prompt: Text("例如 5000"))
                .font(.title3.monospacedDigit())
            Text("预算只统计支出，收入和账户转账不会占用预算。")
                .font(.subheadline).foregroundStyle(.secondary)
            HStack {
                if model.budgetSnapshot.budgetCents != nil {
                    Button("清除预算", role: .destructive) {
                        if model.setBudget(nil) { dismiss() }
                    }
                }
                Spacer()
                Button("取消") { dismiss() }
                Button("保存") {
                    if let cents = Money.parseCents(amountText), cents > 0, model.setBudget(cents) { dismiss() }
                }
                .buttonStyle(.borderedProminent)
                .disabled((Money.parseCents(amountText) ?? 0) <= 0)
            }
        }
        .padding(24)
        .frame(width: 420)
        .onAppear {
            if let cents = model.budgetSnapshot.budgetCents {
                amountText = String(format: "%.2f", Double(cents) / 100)
            }
        }
    }
}
