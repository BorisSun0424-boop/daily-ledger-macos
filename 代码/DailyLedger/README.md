# 日常记账

原生 macOS 离线记账 App，依据 V0.1 PRD 实现。

## 功能

- 收入、支出和账户转账
- 本地账户及余额管理
- 月度收支、分类、上月对比和前三分类统计
- 月度总预算和温和提醒
- 可编辑分类及历史账目迁移
- 所有数据保存在本机，不联网

## 开发与测试

```sh
swift test
swift build
```

## 生成 App

```sh
./Scripts/package_app.sh
```

产物位于 `dist/日常记账.app`。首次运行会在当前用户的 Application Support 目录创建 `DailyLedger/ledger.json`。
