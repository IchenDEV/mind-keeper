import Foundation

struct DemoDataProvider {
    static func createDemoTasks() -> [TaskItem] {
        [
            makeUrgentTask(),
            makeAggregatedSlackTask(),
            makeTask(
                title: "回复张总的项目方案邮件",
                body: "Q3 预算审批流程需要确认，截止周五",
                source: .notification, app: "邮件", bundleId: "com.apple.mail",
                category: .work, urgency: 8, importance: 9, priority: 8.5
            ),
            makeTask(
                title: "团队周会 14:00",
                body: "会议室 A301，需要准备上周进度汇报",
                source: .notification, app: "日历", bundleId: "com.apple.iCal",
                category: .work, urgency: 7, importance: 7, priority: 7.0
            ),
            makeTask(
                title: "李明: 晚上一起吃饭吗？",
                body: "好久没见了，新开了一家日料",
                source: .notification, app: "信息", bundleId: "com.apple.MobileSMS",
                sender: "李明", category: .social, urgency: 3, importance: 4, priority: 3.5
            ),
            makeTask(
                title: "macOS 26.1 更新可用",
                body: "包含安全更新和性能改进",
                source: .notification, app: "系统设置",
                bundleId: "com.apple.Preferences",
                category: .system, urgency: 2, importance: 3, priority: 2.5
            ),
            makeAggregatedMailTask(),
            makeTask(
                title: "完成代码审查 #237",
                body: "新增用户认证模块，需要 review",
                source: .manual, app: nil, bundleId: nil,
                category: .work, urgency: 5, importance: 6, priority: 5.5
            ),
        ]
    }

    private static func makeUrgentTask() -> TaskItem {
        let task = makeTask(
            title: "紧急：生产环境数据库异常",
            body: "DB 主节点 CPU 95%，多个服务响应超时，需要立即处理",
            source: .notification, app: "PagerDuty",
            bundleId: "com.pagerduty.app",
            sender: "运维监控", category: .work,
            urgency: 10, importance: 10, priority: 10.0,
            minutesAgo: 2
        )
        task.isUrgent = true
        return task
    }

    private static func makeAggregatedSlackTask() -> TaskItem {
        let task = makeTask(
            title: "#backend 部署讨论",
            body: "王强: @你 部署完成了吗？",
            source: .notification, app: "Slack",
            bundleId: "com.tinyspeck.slackmacgap",
            sender: "王强", category: .work,
            urgency: 7, importance: 7, priority: 7.5,
            minutesAgo: 8
        )
        task.mergeNotification(
            title: "王强: 测试环境已经准备好了",
            body: "#backend 频道", sender: "王强"
        )
        task.mergeNotification(
            title: "李华: CI 流水线跑完了，全部通过",
            body: "#backend 频道", sender: "李华"
        )
        return task
    }

    private static func makeAggregatedMailTask() -> TaskItem {
        let task = makeTask(
            title: "信用卡账单与还款",
            body: "本月消费 ¥3,280.50，还款日 3月15日",
            source: .notification, app: "邮件",
            bundleId: "com.apple.mail",
            category: .finance, urgency: 6, importance: 8, priority: 7.0,
            minutesAgo: 45
        )
        task.mergeNotification(
            title: "招商银行: 您的信用卡账单已出",
            body: "本期应还金额 ¥3,280.50"
        )
        return task
    }

    private static func makeTask(
        title: String, body: String, source: TaskSource,
        app: String?, bundleId: String?, sender: String? = nil,
        category: TaskCategory, urgency: Int, importance: Int,
        priority: Double, minutesAgo: Int = Int.random(in: 1...120)
    ) -> TaskItem {
        let task = TaskItem(
            title: title, body: body, source: source,
            appName: app, appBundleId: bundleId, sender: sender,
            urgency: urgency, importance: importance
        )
        task.category = category
        task.priority = priority
        task.createdAt = Date().addingTimeInterval(-Double(minutesAgo * 60))
        return task
    }
}
