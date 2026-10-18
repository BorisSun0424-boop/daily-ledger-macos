import SwiftUI
import Charts
import DailyLedgerCore

struct OverviewView: View {
    @ObservedObject var model: AppModel
    @State private var showBudgetEditor = false

    private var stats: MonthlyStatistics { model.statistics }
    private var budget: BudgetSnapshot { model.budgetSnapshot }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("月度概览").font(.largeTitle.bold())

                HStack(spacing: 14) {
                    SummaryCard(title: "收入", cents: stats.incomeCents, color: .green, icon: "arrow.down.left")
                    SummaryCard(title: "支出", cents: stats.expenseCents, color: .orange, icon: "arrow.up.right")
                    SummaryCard(title: "结余", cents: stats.netCents, color: stats.netCents >= 0 ? .blue : .red, icon: "equal")
                }

                BudgetCard(snapshot: budget) { showBudgetEditor = true }

                HStack(alignment: .top, spacing: 16) {
                    GroupBox("分类支出") {
                        if stats.categorySpending.isEmpty {
                            EmptyStateView(icon: "chart.bar", title: "还没有支出", message: "新增一笔支出后，这里会显示分类统计。")
                                .frame(minHeight: 230)
                        } else {
                            Chart(stats.categorySpending) { item in
                                BarMark(x: .value("金额", item.amountCents), y: .value("分类", item.name))
                                    .foregroundStyle(.orange.gradient)
                                    .annotation(position: .trailing) {
                                        Text("\(Int(item.fraction * 100))%")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                            }
                            .chartXAxis(.hidden)
                            .frame(minHeight: 230)
                            .padding(.top, 8)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 16) {
                        ComparisonCard(current: stats.expenseCents, previous: stats.previousMonthExpenseCents)
                        TopCategoriesCard(items: stats.topCategories)
                    }
                    .frame(width: 300)
                }
            }
            .padding(28)
        }
        .sheet(isPresented: $showBudgetEditor) { BudgetEditorView(model: model) }
    }
}

private struct SummaryCard: View {
    let title: String
    let cents: Int64
    let color: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon).foregroundStyle(.secondary)
            AmountText(cents: cents, color: color).font(.title2.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct BudgetCard: View {
    let snapshot: BudgetSnapshot
    let edit: () -> Void

    private var tint: Color {
        switch snapshot.level {
        case .notSet, .comfortable: .blue
        case .approaching: .orange
        case .exceeded: .red
        }
    }

    private var message: String {
        guard let remaining = snapshot.remainingCents else { return "设置月度预算，了解这个月还能花多少钱。" }
        if remaining >= 0 { return "本月还可以使用 \(Money.format(cents: remaining))" }
        return "本月比计划多支出了 \(Money.format(cents: abs(remaining)))"
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(message).font(.headline)
                        Text("已花 \(Money.format(cents: snapshot.spentCents)) · 本月剩余 \(snapshot.remainingDays) 天")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(snapshot.budgetCents == nil ? "设置预算" : "修改预算", action: edit)
                }
                if snapshot.budgetCents != nil {
                    ProgressView(value: min(snapshot.progress, 1)).tint(tint)
                }
            }
            .padding(6)
        } label: {
            Label("月度预算", systemImage: "gauge.with.dots.needle.50percent")
        }
    }
}

private struct ComparisonCard: View {
    let current: Int64
    let previous: Int64

    var body: some View {
        GroupBox("与上月相比") {
            VStack(alignment: .leading, spacing: 8) {
                AmountText(cents: current - previous, color: current <= previous ? .green : .orange)
                    .font(.title3.bold())
                Text(previous == 0 ? "上月没有支出记录" : (current <= previous ? "比上月支出更少" : "比上月支出更多"))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
        }
    }
}

private struct TopCategoriesCard: View {
    let items: [CategorySpending]

    var body: some View {
        GroupBox("支出前三") {
            if items.isEmpty {
                Text("暂无数据").foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        HStack {
                            Text("\(index + 1)").font(.caption.bold()).foregroundStyle(.secondary)
                                .frame(width: 18, height: 18).background(.quaternary, in: Circle())
                            Text(item.name)
                            Spacer()
                            AmountText(cents: item.amountCents)
                        }
                    }
                }.padding(.vertical, 4)
            }
        }
    }
}
