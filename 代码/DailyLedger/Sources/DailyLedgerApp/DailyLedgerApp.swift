import SwiftUI
import DailyLedgerCore

@main
struct DailyLedgerApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("日常记账") {
            ContentView(model: model)
                .frame(minWidth: 960, minHeight: 680)
        }
        .defaultSize(width: 1120, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新增记录") { model.showNewEntry = true }
                    .keyboardShortcut("n", modifiers: .command)
                    .disabled(model.data.accounts.filter(\.isActive).isEmpty || model.isReadOnly)
            }
        }

        Settings {
            SettingsView(model: model)
                .frame(width: 620, height: 460)
        }
    }
}
