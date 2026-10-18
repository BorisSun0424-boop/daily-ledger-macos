import SwiftUI
import DailyLedgerCore

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        TabView {
            CategorySettingsView(model: model)
                .tabItem { Label("分类", systemImage: "square.grid.2x2") }
            PrivacySettingsView()
                .tabItem { Label("本地数据", systemImage: "lock.macwindow") }
        }
        .padding(20)
    }
}

private struct CategorySettingsView: View {
    @ObservedObject var model: AppModel
    @State private var kind: CategoryKind = .expense
    @State private var selectedID: UUID?
    @State private var editorMode: EditorMode?
    @State private var migrationSource: LedgerCategory?

    enum EditorMode: Identifiable {
        case add
        case rename(LedgerCategory)
        var id: String {
            switch self {
            case .add: "add"
            case .rename(let category): category.id.uuidString
            }
        }
    }

    private var categories: [LedgerCategory] {
        model.data.categories.filter { $0.kind == kind }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("分类类型", selection: $kind) {
                Text("支出分类").tag(CategoryKind.expense)
                Text("收入分类").tag(CategoryKind.income)
            }
            .pickerStyle(.segmented)

            List(categories, selection: $selectedID) { category in
                HStack {
                    Text(category.name)
                    Spacer()
                    if category.isSystem { Text("预设").font(.caption).foregroundStyle(.secondary) }
                }
                .tag(category.id)
            }

            HStack {
                Button { editorMode = .add } label: { Image(systemName: "plus") }
                Button { deleteSelected() } label: { Image(systemName: "minus") }
                    .disabled(selectedID == nil)
                Spacer()
                Button("重命名") {
                    if let selected = categories.first(where: { $0.id == selectedID }) { editorMode = .rename(selected) }
                }
                .disabled(selectedID == nil)
            }
        }
        .sheet(item: $editorMode) { mode in
            CategoryEditorSheet(model: model, kind: kind, mode: mode)
        }
        .sheet(item: $migrationSource) { source in
            CategoryMigrationSheet(model: model, source: source)
        }
    }

    private func deleteSelected() {
        guard let category = categories.first(where: { $0.id == selectedID }) else { return }
        if model.data.entries.contains(where: { $0.categoryID == category.id }) {
            migrationSource = category
        } else if model.deleteCategory(category) {
            selectedID = nil
        }
    }
}

private struct CategoryEditorSheet: View {
    @ObservedObject var model: AppModel
    let kind: CategoryKind
    let mode: CategorySettingsView.EditorMode
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(isAdding ? "新增分类" : "重命名分类").font(.title2.bold())
            TextField("分类名称", text: $name)
            HStack {
                Button("取消") { dismiss() }
                Spacer()
                Button("保存") {
                    let success: Bool
                    switch mode {
                    case .add: success = model.addCategory(name: name, kind: kind)
                    case .rename(let category): success = model.renameCategory(category, name: name)
                    }
                    if success { dismiss() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24).frame(width: 380)
        .onAppear {
            if case .rename(let category) = mode { name = category.name }
        }
    }

    private var isAdding: Bool {
        if case .add = mode { return true }
        return false
    }
}

private struct CategoryMigrationSheet: View {
    @ObservedObject var model: AppModel
    let source: LedgerCategory
    @Environment(\.dismiss) private var dismiss
    @State private var destinationID: UUID?

    private var destinations: [LedgerCategory] {
        model.data.categories.filter { $0.kind == source.kind && $0.id != source.id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("迁移“\(source.name)”的历史账目").font(.title2.bold())
            Text("这个分类已有历史账目。选择一个新分类后，历史账目会被转移，再删除原分类。")
                .foregroundStyle(.secondary)
            Picker("转移到", selection: $destinationID) {
                ForEach(destinations) { Text($0.name).tag(Optional($0.id)) }
            }
            HStack {
                Button("取消") { dismiss() }
                Spacer()
                Button("迁移并删除", role: .destructive) {
                    if let destination = destinations.first(where: { $0.id == destinationID }),
                       model.migrateAndDeleteCategory(source, to: destination) { dismiss() }
                }
                .disabled(destinationID == nil)
            }
        }
        .padding(24).frame(width: 460)
        .onAppear { destinationID = destinations.first?.id }
    }
}

private struct PrivacySettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("数据只保存在这台 Mac", systemImage: "lock.shield.fill")
                .font(.title2.bold()).foregroundStyle(.blue)
            Text("日常记账没有账户系统、云同步或网络接口。账目保存在当前用户的 Application Support/DailyLedger 文件夹中。")
                .foregroundStyle(.secondary)
            Divider()
            LabeledContent("联网", value: "不需要")
            LabeledContent("注册登录", value: "不需要")
            LabeledContent("云端数据", value: "无")
            Spacer()
        }
        .padding(18)
    }
}
