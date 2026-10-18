import SwiftUI
import DailyLedgerCore

struct OnboardingView: View {
    @ObservedObject var model: AppModel
    @State private var accountName = "现金"
    @State private var openingBalance = "0"
    @State private var budget = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Image(systemName: "wallet.bifold.fill")
                .font(.system(size: 42)).foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 8) {
                Text("开始使用日常记账").font(.largeTitle.bold())
                Text("所有账目只保存在这台 Mac，不需要注册，也不会上传到网络。")
                    .foregroundStyle(.secondary)
            }

            GroupBox("第一个账户") {
                Form {
                    TextField("账户名称", text: $accountName)
                    TextField("当前余额", text: $openingBalance)
                }
                .formStyle(.grouped)
            }

            GroupBox("月度预算（选填）") {
                TextField("例如 5000", text: $budget)
                    .textFieldStyle(.roundedBorder).padding(8)
            }

            HStack {
                Text("之后可以继续添加银行卡、微信和支付宝等账户。")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("进入 App") { finish() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!canFinish)
            }
        }
        .padding(32)
        .frame(width: 560)
    }

    private var canFinish: Bool {
        !accountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && Money.parseCents(openingBalance) != nil
    }

    private func finish() {
        guard let opening = Money.parseCents(openingBalance) else { return }
        let budgetCents = budget.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : Money.parseCents(budget)
        _ = model.finishOnboarding(accountName: accountName, openingBalanceCents: opening, budgetCents: budgetCents)
    }
}
