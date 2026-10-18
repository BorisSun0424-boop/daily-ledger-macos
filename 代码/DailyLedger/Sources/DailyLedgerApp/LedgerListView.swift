import SwiftUI
import DailyLedgerCore

struct LedgerListView: View {
    @ObservedObject var model: AppModel
    @State private var selectedEntryID: UUID?
    @State private var editingEntry: LedgerEntry?
    @State private var deletingEntry: LedgerEntry?

    private var selectedEntry: LedgerEntry? {
        model.statistics.entries.first { $0.id == selectedEntryID }
    }

    private var groupedEntries: [(Date, [LedgerEntry])] {
        let grouped = Dictionary(grouping: model.statistics.entries) { Calendar.current.startOfDay(for: $0.date) }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0]!.sorted { $0.date > $1.date }) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("账目明细").font(.largeTitle.bold()).padding(.horizontal, 24).padding(.top, 22)
            if groupedEntries.isEmpty {
                EmptyStateView(icon: "list.bullet.rectangle", title: "这个月还没有账目", message: "点击右上角“新增记录”开始记账。")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HSplitView {
                    List(selection: $selectedEntryID) {
                        ForEach(groupedEntries, id: \.0) { day, entries in
                            Section {
                                ForEach(entries) { entry in
                                    EntryRow(entry: entry, model: model)
                                        .tag(entry.id)
                                        .contextMenu {
                                            Button("编辑") { editingEntry = entry }
                                            Button("删除", role: .destructive) { deletingEntry = entry }
                                        }
                                }
                            } header: {
                                HStack {
                                    Text(day, format: .dateTime.month().day().weekday())
                                    Spacer()
                                    AmountText(cents: dayExpense(entries), color: .secondary)
                                }
                            }
                        }
                    }
                    .frame(minWidth: 430)

                    if let selectedEntry {
                        EntryDetailView(entry: selectedEntry, model: model) {
                            editingEntry = selectedEntry
                        } delete: {
                            deletingEntry = selectedEntry
                        }
                        .frame(minWidth: 280)
                    } else {
                        EmptyStateView(icon: "sidebar.right", title: "选择一笔账目", message: "查看完整信息，或进行编辑和删除。")
                            .frame(minWidth: 280)
                    }
                }
            }
        }
        .sheet(item: $editingEntry) { EntryEditorView(model: model, existing: $0) }
        .confirmationDialog("删除这笔账目？", isPresented: Binding(
            get: { deletingEntry != nil },
            set: { if !$0 { deletingEntry = nil } }
        )) {
            Button("删除", role: .destructive) {
                if let deletingEntry { _ = model.deleteEntry(deletingEntry) }
                deletingEntry = nil
            }
        } message: {
            Text("删除后，账户余额和月度统计会立即更新。")
        }
    }

    private func dayExpense(_ entries: [LedgerEntry]) -> Int64 {
        entries.filter { $0.kind == .expense }.reduce(0) { $0 + $1.amountCents }
    }
}

private struct EntryRow: View {
    let entry: LedgerEntry
    @ObservedObject var model: AppModel

    private var title: String {
        if entry.kind == .transfer { return "账户转账" }
        return model.data.categories.first { $0.id == entry.categoryID }?.name ?? "未分类"
    }

    private var accountName: String {
        let source = model.data.accounts.first { $0.id == entry.accountID }?.name ?? "未知账户"
        guard entry.kind == .transfer else { return source }
        let destination = model.data.accounts.first { $0.id == entry.destinationAccountID }?.name ?? "未知账户"
        return "\(source) → \(destination)"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.kind == .expense ? "arrow.up.right.circle.fill" : (entry.kind == .income ? "arrow.down.left.circle.fill" : "arrow.left.arrow.right.circle.fill"))
                .font(.title2)
                .foregroundStyle(entry.kind == .expense ? .orange : (entry.kind == .income ? .green : .blue))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(entry.note.isEmpty ? accountName : "\(accountName) · \(entry.note)")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            AmountText(cents: entry.amountCents, color: entry.kind == .expense ? .orange : (entry.kind == .income ? .green : .primary))
        }
        .padding(.vertical, 5)
    }
}

private struct EntryDetailView: View {
    let entry: LedgerEntry
    @ObservedObject var model: AppModel
    let edit: () -> Void
    let delete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(entry.kind == .expense ? "支出" : (entry.kind == .income ? "收入" : "转账"))
                .font(.headline).foregroundStyle(.secondary)
            AmountText(cents: entry.amountCents).font(.largeTitle.bold())
            Divider()
            DetailLine(label: "日期", value: entry.date.formatted(date: .long, time: .omitted))
            if entry.kind != .transfer {
                DetailLine(label: "分类", value: model.data.categories.first { $0.id == entry.categoryID }?.name ?? "未分类")
            }
            DetailLine(label: entry.kind == .transfer ? "转出账户" : "账户", value: model.data.accounts.first { $0.id == entry.accountID }?.name ?? "未知账户")
            if entry.kind == .transfer {
                DetailLine(label: "转入账户", value: model.data.accounts.first { $0.id == entry.destinationAccountID }?.name ?? "未知账户")
            }
            if !entry.note.isEmpty { DetailLine(label: "备注", value: entry.note) }
            Spacer()
            HStack {
                Button("删除", role: .destructive, action: delete)
                Spacer()
                Button("编辑", action: edit).buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
    }
}

private struct DetailLine: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value)
        }
    }
}
