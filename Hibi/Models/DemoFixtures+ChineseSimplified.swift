import Foundation
import SwiftUI

extension DemoFixtures {
    // swiftlint:disable function_body_length
    static func makeChineseSimplifiedEvents() -> EventMap {
        var out: EventMap = [:]

        func add(_ y: Int, _ m: Int, _ day: Int, _ event: CalendarEvent) {
            let key = MonthKey(year: y, month: m)
            out[key, default: [:]][day, default: []].append(event)
        }

        func timed(
            _ id: String,
            _ y: Int, _ m: Int, _ day: Int,
            _ h1: Int, _ m1: Int, _ h2: Int, _ m2: Int,
            title: String, tint: Color, location: String? = nil,
            recurring: Bool = false
        ) {
            let s = date(y, m, day, h: h1, min: m1)
            let e = date(y, m, day, h: h2, min: m2)
            add(y, m, day, CalendarEvent(
                id: id, eventIdentifier: nil, day: day,
                startDate: s, endDate: e,
                title: title, tint: tint, location: location, allDay: false,
                isRecurring: recurring
            ))
        }

        // MARK: 二月
        add(2026, 2, 1, CalendarEvent(id: "demo-feb-101", eventIdentifier: nil, day: 1, title: "月度预算复盘", tint: butter, allDay: true))
        timed("demo-feb-101b", 2026, 2, 1, 15, 0, 15, 45, title: "季度规划 — 财务", tint: sea, location: "腾讯会议")
        timed("demo-feb-102", 2026, 2, 2, 9, 0, 9, 45, title: "晨间瑜伽", tint: mint, location: "静安瑜伽馆", recurring: true)
        add(2026, 2, 3, CalendarEvent(id: "demo-feb-001", eventIdentifier: nil, day: 3, title: "立春", tint: rose, allDay: true))
        timed("demo-feb-001b", 2026, 2, 3, 19, 0, 22, 0, title: "家庭聚餐", tint: lilac, location: "家")
        timed("demo-feb-103", 2026, 2, 4, 12, 0, 12, 30, title: "牙科 — 洗牙", tint: sea, location: "仁爱牙科")
        timed("demo-feb-104", 2026, 2, 5, 18, 0, 19, 30, title: "烹饪课: 手工面", tint: peach, location: "悦食烹饪工作室")
        // 2/6: sparse
        timed("demo-feb-106", 2026, 2, 7, 10, 30, 11, 30, title: "读书会", tint: sky, location: "钟书阁书店")
        timed("demo-feb-106b", 2026, 2, 7, 16, 0, 17, 0, title: "采购 + 备菜", tint: butter, location: "Ole'精品超市")
        timed("demo-feb-107", 2026, 2, 8, 15, 0, 16, 0, title: "孩子足球训练", tint: coral, location: "徐家汇体育场")
        timed("demo-feb-108", 2026, 2, 9, 8, 30, 9, 15, title: "一对一沟通", tint: sea, location: "飞书 — 会议室A", recurring: true)
        timed("demo-feb-109", 2026, 2, 10, 19, 0, 20, 30, title: "爵士现场", tint: lilac, location: "JZ Club")
        add(2026, 2, 11, CalendarEvent(id: "demo-feb-110", eventIdentifier: nil, day: 11, title: "公司年会", tint: butter, allDay: true))
        timed("demo-feb-110b", 2026, 2, 11, 14, 0, 15, 30, title: "取车 — 保养完成", tint: coral, location: "4S店")
        // 2/12: sparse
        timed("demo-feb-112", 2026, 2, 13, 17, 30, 18, 30, title: "心理咨询", tint: sky, recurring: true)
        add(2026, 2, 14, CalendarEvent(
            id: "demo-feb-002", eventIdentifier: nil, day: 14,
            startDate: date(2026, 2, 14, h: 10, min: 0),
            endDate: date(2026, 2, 14, h: 12, min: 30),
            title: "情人节 — 早午餐", tint: peach, location: "外滩餐厅", allDay: false
        ))
        timed("demo-feb-002b", 2026, 2, 14, 18, 30, 20, 0, title: "黄昏漫步 — 滨江", tint: rose, location: "徐汇滨江")
        timed("demo-feb-113", 2026, 2, 15, 14, 0, 15, 30, title: "美术馆 — 特展", tint: lilac, location: "上海博物馆")
        timed("demo-feb-114", 2026, 2, 16, 11, 0, 12, 0, title: "家长会", tint: coral, location: "实验小学")
        timed("demo-feb-115", 2026, 2, 17, 16, 0, 17, 0, title: "吉他课", tint: sea)
        // 2/18: sparse
        timed("demo-feb-117", 2026, 2, 19, 20, 0, 22, 30, title: "篮球比赛", tint: sky, location: "东方体育中心")
        for day in 20 ... 22 {
            add(2026, 2, day, CalendarEvent(id: "demo-feb-onsen-\(day)", eventIdentifier: nil, day: day, title: "春节假期 — 回家", tint: sky, allDay: true))
        }
        timed("demo-feb-onsen21b", 2026, 2, 21, 17, 0, 18, 30, title: "年夜饭 — 团圆", tint: peach, location: "老家")
        timed("demo-feb-118", 2026, 2, 23, 13, 0, 14, 0, title: "午餐 — 投资人", tint: peach, location: "国金中心餐厅")
        timed("demo-feb-118b", 2026, 2, 23, 16, 30, 17, 30, title: "看房 — 新办公室", tint: mint, location: "WeWork 南京西路")
        // 2/24: sparse
        add(2026, 2, 25, CalendarEvent(id: "demo-feb-120", eventIdentifier: nil, day: 25, title: "个税年度汇算准备", tint: rose, allDay: true))
        timed("demo-feb-121", 2026, 2, 26, 8, 0, 8, 30, title: "高铁去杭州", tint: lilac, location: "上海虹桥站")
        timed("demo-feb-122", 2026, 2, 27, 12, 30, 13, 30, title: "设计评审", tint: coral, location: "Figma / 总部")
        add(2026, 2, 28, CalendarEvent(id: "demo-feb-123", eventIdentifier: nil, day: 28, title: "冬装促销最后一天", tint: butter, allDay: true))

        // MARK: 三月
        add(2026, 3, 1, CalendarEvent(id: "demo-mar-101", eventIdentifier: nil, day: 1, title: "春季换季整理", tint: lilac, allDay: true))
        timed("demo-mar-101b", 2026, 3, 1, 14, 0, 15, 0, title: "旧衣捐赠", tint: coral, location: "旧物回收点")
        timed("demo-mar-102", 2026, 3, 2, 9, 30, 10, 30, title: "全员大会", tint: sea, location: "公司礼堂")
        timed("demo-mar-102b", 2026, 3, 2, 15, 0, 16, 0, title: "设计评审 — 跟进", tint: lilac, location: "Figma")
        add(2026, 3, 3, CalendarEvent(id: "demo-mar-hina", eventIdentifier: nil, day: 3, title: "元宵节", tint: rose, allDay: true))
        timed("demo-mar-103", 2026, 3, 3, 17, 0, 18, 15, title: "包汤圆", tint: mint, location: "家")
        timed("demo-mar-104", 2026, 3, 4, 12, 0, 13, 0, title: "午餐分享会 — SwiftUI", tint: peach, location: "研发休息区")
        timed("demo-mar-104b", 2026, 3, 4, 18, 0, 19, 0, title: "夜跑 — 世纪公园一圈", tint: sky, location: "世纪公园")
        add(2026, 3, 5, CalendarEvent(id: "demo-mar-105", eventIdentifier: nil, day: 5, title: "提交报销", tint: butter, allDay: true))
        // 3/6: sparse
        timed("demo-mar-107", 2026, 3, 7, 11, 0, 12, 30, title: "和父母早午餐", tint: rose, location: "新天地餐厅")
        add(2026, 3, 8, CalendarEvent(
            id: "demo-mar-001", eventIdentifier: nil, day: 8,
            startDate: date(2026, 3, 8, h: 11, min: 0),
            endDate: date(2026, 3, 8, h: 13, min: 0),
            title: "三八妇女节 — 家庭茶聚", tint: lilac, location: "家", allDay: false
        ))
        timed("demo-mar-108", 2026, 3, 9, 14, 0, 15, 30, title: "扫街拍照", tint: coral, location: "武康路")
        timed("demo-mar-110", 2026, 3, 10, 8, 0, 9, 0, title: "牙科 — 定期检查", tint: sea, location: "仁爱牙科")
        timed("demo-mar-111", 2026, 3, 11, 19, 30, 21, 0, title: "艺术影院 — 观影", tint: lilac, location: "大光明电影院")
        // 3/12: sparse
        timed("demo-mar-113", 2026, 3, 13, 16, 0, 17, 30, title: "理发", tint: peach, location: "Tony 造型")
        timed("demo-mar-114", 2026, 3, 14, 9, 0, 11, 0, title: "挑选礼物", tint: mint, location: "久光百货")
        timed("demo-mar-114b", 2026, 3, 14, 15, 0, 16, 30, title: "午睡 + 洗衣", tint: butter)
        add(2026, 3, 15, CalendarEvent(
            id: "demo-mar-002", eventIdentifier: nil, day: 15,
            startDate: date(2026, 3, 15, h: 15, min: 30),
            endDate: date(2026, 3, 15, h: 16, min: 30),
            title: "口腔检查", tint: mint, location: "仁爱牙科", allDay: false
        ))
        add(2026, 3, 16, CalendarEvent(id: "demo-mar-115", eventIdentifier: nil, day: 16, title: "业主委员会", tint: sky, location: "小区会议室", allDay: true))
        timed("demo-mar-116", 2026, 3, 17, 18, 0, 19, 30, title: "网球课", tint: coral, location: "3号场")
        // 3/18: sparse
        timed("demo-mar-119", 2026, 3, 19, 7, 30, 8, 15, title: "动感单车", tint: rose, location: "乐刻健身")
        timed("demo-mar-120", 2026, 3, 20, 13, 0, 14, 30, title: "午餐 — 导师咖啡", tint: peach, location: "Manner 咖啡")
        timed("demo-mar-120b", 2026, 3, 20, 17, 0, 18, 0, title: "代码评审 — 日历小组件", tint: sea, location: "腾讯会议")
        add(2026, 3, 21, CalendarEvent(id: "demo-mar-121", eventIdentifier: nil, day: 21, title: "春分 — 佘山徒步", tint: mint, location: "佘山", allDay: true))
        timed("demo-mar-122", 2026, 3, 22, 15, 0, 16, 30, title: "孩子生日派对", tint: lilac, location: "儿童乐园")
        timed("demo-mar-122b", 2026, 3, 22, 10, 0, 11, 30, title: "派对准备（布置）", tint: sky, location: "儿童乐园")
        timed("demo-mar-123", 2026, 3, 23, 9, 30, 10, 30, title: "法务评审 — 合同", tint: butter, location: "WeWork 静安")
        // 3/24: sparse
        timed("demo-mar-125", 2026, 3, 25, 11, 30, 12, 30, title: "答疑时间", tint: coral, location: "飞书会议")
        timed("demo-mar-126", 2026, 3, 26, 17, 0, 18, 0, title: "遛狗训练课", tint: sea, location: "中山公园")
        timed("demo-mar-127", 2026, 3, 27, 8, 45, 9, 30, title: "送孩子上学", tint: peach)
        add(2026, 3, 28, CalendarEvent(id: "demo-mar-003", eventIdentifier: nil, day: 28, title: "大扫除 — 春季焕新", tint: butter, allDay: true))
        timed("demo-mar-128", 2026, 3, 29, 14, 0, 15, 0, title: "公益跑 — 领号码布", tint: rose, location: "上海体育场")
        // 3/30: sparse
        add(2026, 3, 31, CalendarEvent(id: "demo-mar-130", eventIdentifier: nil, day: 31, title: "提交 Q1 总结", tint: sky, allDay: true))

        // MARK: 四月（充实 — 主演示月）
        add(2026, 4, 1, CalendarEvent(id: "demo-apr-101", eventIdentifier: nil, day: 1, title: "新财年启动", tint: butter, allDay: true))
        timed("demo-apr-101b", 2026, 4, 1, 11, 0, 11, 45, title: "新同事欢迎午餐", tint: lilac, location: "食堂")
        timed("demo-apr-102", 2026, 4, 2, 9, 0, 10, 0, title: "晨会", tint: sea, location: "腾讯会议")
        timed("demo-apr-103", 2026, 4, 2, 15, 30, 16, 30, title: "和邻居奶奶喝茶", tint: peach, location: "院子")
        add(2026, 4, 3, CalendarEvent(
            id: "demo-apr-001", eventIdentifier: nil, day: 3,
            startDate: date(2026, 4, 3, h: 10, min: 0),
            endDate: date(2026, 4, 3, h: 11, min: 30),
            title: "团队晨会 & 路线图", tint: sea, location: "腾讯会议", allDay: false
        ))
        timed("demo-apr-001b", 2026, 4, 3, 14, 0, 15, 30, title: "路线图 — 干系人答疑", tint: lilac, location: "腾讯会议")
        timed("demo-apr-104", 2026, 4, 4, 11, 0, 12, 30, title: "赏樱早午餐", tint: rose, location: "顾村公园")
        timed("demo-apr-104b", 2026, 4, 4, 16, 0, 17, 30, title: "赏樱 — 占位", tint: mint, location: "顾村公园")
        add(2026, 4, 5, CalendarEvent(
            id: "demo-apr-002", eventIdentifier: nil, day: 5,
            startDate: date(2026, 4, 5, h: 19, min: 30),
            endDate: date(2026, 4, 5, h: 22, min: 0),
            title: "古典音乐会", tint: lilac, location: "上海音乐厅", allDay: false
        ))
        timed("demo-apr-005b", 2026, 4, 5, 10, 0, 11, 30, title: "看电影 — 全家", tint: butter, location: "万达影城")
        // 4/6: sparse
        timed("demo-apr-106", 2026, 4, 7, 18, 0, 19, 30, title: "足球补训", tint: coral, location: "徐家汇体育场")
        timed("demo-apr-106b", 2026, 4, 7, 8, 0, 8, 45, title: "邮件整理 — 专注时间", tint: sea)
        timed("demo-apr-107", 2026, 4, 8, 12, 0, 12, 45, title: "午间散步", tint: sky)
        timed("demo-apr-108", 2026, 4, 9, 14, 0, 15, 30, title: "用户研究", tint: lilac, location: "2号实验室")
        timed("demo-apr-108b", 2026, 4, 9, 18, 0, 19, 0, title: "原型修改 — 交接", tint: peach, location: "2号实验室")
        for day in 10 ... 11 {
            add(2026, 4, day, CalendarEvent(id: "demo-apr-tech-\(day)", eventIdentifier: nil, day: day, title: "技术大会", tint: sky, allDay: true))
        }
        timed("demo-apr-tech11b", 2026, 4, 11, 17, 0, 18, 30, title: "大会 — 撤展", tint: coral, location: "国家会展中心")
        // 4/12: sparse
        timed("demo-apr-109", 2026, 4, 13, 10, 0, 11, 0, title: "绩效评估 — 启动", tint: butter, location: "HR 系统")
        timed("demo-apr-109b", 2026, 4, 13, 14, 30, 15, 45, title: "一对一 — 设计负责人", tint: lilac, location: "静音室")
        timed("demo-apr-110", 2026, 4, 14, 19, 0, 20, 30, title: "相声专场", tint: peach, location: "德云社")
        timed("demo-apr-111", 2026, 4, 15, 9, 30, 10, 45, title: "架构评审", tint: sea, location: "作战室")
        timed("demo-apr-111b", 2026, 4, 15, 12, 0, 13, 0, title: "午餐 — 平台团队", tint: peach, location: "园区咖啡馆")
        timed("demo-apr-112", 2026, 4, 16, 16, 0, 17, 0, title: "还租车", tint: coral, location: "机场")
        timed("demo-apr-112b", 2026, 4, 16, 10, 30, 11, 30, title: "航班延误缓冲", tint: butter, location: "休息室")
        timed("demo-apr-113", 2026, 4, 17, 11, 30, 12, 30, title: "皮肤科", tint: mint, location: "华山医院皮肤科")

        // 2026-04-18 (SampleData “今天”)
        add(2026, 4, 18, CalendarEvent(
            id: "demo-apr-today-001", eventIdentifier: nil, day: 18,
            startDate: date(2026, 4, 18, h: 8, min: 0),
            endDate: date(2026, 4, 18, h: 9, min: 30),
            title: "早餐 — 和美琪", tint: peach, location: "麦田面包房", allDay: false
        ))
        timed("demo-apr-today-progress", 2026, 4, 18, 10, 0, 20, 0, title: "App Store 收尾 — 专注时段", tint: sea, location: "家庭办公室", recurring: true)
        add(2026, 4, 18, CalendarEvent(
            id: "demo-apr-today-002", eventIdentifier: nil, day: 18,
            startDate: date(2026, 4, 18, h: 12, min: 30),
            endDate: date(2026, 4, 18, h: 13, min: 45),
            title: "团队午餐", tint: mint, location: "意餐厅", allDay: false,
            isRecurring: true
        ))
        add(2026, 4, 18, CalendarEvent(id: "demo-apr-today-003", eventIdentifier: nil, day: 18, title: "家庭聚会（全天）", tint: rose, location: "爷爷奶奶家", allDay: true))
        add(2026, 4, 18, CalendarEvent(
            id: "demo-apr-today-004", eventIdentifier: nil, day: 18,
            startDate: date(2026, 4, 18, h: 20, min: 15),
            endDate: date(2026, 4, 18, h: 23, min: 15),
            title: "电影:沙丘 2", tint: coral, location: "万达影城 IMAX", allDay: false
        ))

        timed("demo-apr-114", 2026, 4, 19, 10, 0, 11, 30, title: "周日慢跑", tint: mint, location: "世纪公园")
        timed("demo-apr-114b", 2026, 4, 19, 15, 0, 17, 0, title: "备菜 + 播客", tint: sky)
        timed("demo-apr-115", 2026, 4, 20, 13, 0, 14, 0, title: "薪资审批", tint: butter, location: "财务系统")
        timed("demo-apr-116", 2026, 4, 21, 17, 30, 18, 45, title: "网球双打", tint: sky, location: "球场")
        timed("demo-apr-117", 2026, 4, 22, 8, 0, 8, 45, title: "航班值机", tint: lilac)
        timed("demo-apr-118", 2026, 4, 23, 15, 0, 16, 30, title: "播客录制", tint: peach, location: "家庭录音室")
        timed("demo-apr-118b", 2026, 4, 23, 19, 0, 20, 0, title: "播客初剪", tint: lilac, location: "家庭录音室")
        // 4/24: sparse
        add(2026, 4, 25, CalendarEvent(id: "demo-apr-004", eventIdentifier: nil, day: 25, title: "一日游 — 乌镇", tint: sea, allDay: true))
        timed("demo-apr-004b", 2026, 4, 25, 8, 30, 9, 15, title: "便当 + 准备", tint: butter)
        timed("demo-apr-120", 2026, 4, 26, 14, 0, 15, 0, title: "换盆派对", tint: rose, location: "阳台")
        timed("demo-apr-121", 2026, 4, 27, 9, 0, 10, 0, title: "安全培训（年度）", tint: coral, location: "在线学习")
        timed("demo-apr-122", 2026, 4, 28, 18, 0, 19, 15, title: "烘焙课: 乡村面包", tint: lilac, location: "烘焙工作室")
        add(2026, 4, 29, CalendarEvent(id: "demo-apr-showa", eventIdentifier: nil, day: 29, title: "团队建设日", tint: butter, allDay: true))
        timed("demo-apr-123", 2026, 4, 29, 11, 0, 12, 0, title: "供应商演示 — 分析工具", tint: sea, location: "腾讯会议")
        // 4/30: sparse

        // MARK: 五月
        add(2026, 5, 1, CalendarEvent(id: "demo-may-001", eventIdentifier: nil, day: 1, title: "五一劳动节", tint: rose, allDay: true))
        timed("demo-may-001b", 2026, 5, 1, 8, 30, 9, 30, title: "社区志愿准备", tint: sea, location: "居委会")
        timed("demo-may-101", 2026, 5, 2, 10, 0, 12, 0, title: "跳蚤市场准备", tint: peach, location: "停车场")
        timed("demo-may-101b", 2026, 5, 2, 14, 0, 16, 0, title: "跳蚤市场收摊", tint: butter, location: "停车场")
        add(2026, 5, 3, CalendarEvent(id: "demo-may-kenpo", eventIdentifier: nil, day: 3, title: "五一假期 — 周边游", tint: lilac, allDay: true))
        timed("demo-may-102", 2026, 5, 3, 15, 30, 17, 0, title: "钢琴汇报演出", tint: sky, location: "音乐学院")
        add(2026, 5, 4, CalendarEvent(id: "demo-may-midori", eventIdentifier: nil, day: 4, title: "踏青 — 郊外", tint: mint, allDay: true))
        timed("demo-may-103", 2026, 5, 4, 9, 0, 10, 30, title: "董事会准备", tint: sea, location: "B 会议室")
        add(2026, 5, 5, CalendarEvent(id: "demo-may-kodomo", eventIdentifier: nil, day: 5, title: "立夏", tint: coral, allDay: true))
        timed("demo-may-104", 2026, 5, 5, 12, 15, 13, 0, title: "立夏煮蛋", tint: peach, location: "家")
        timed("demo-may-104b", 2026, 5, 5, 16, 0, 17, 0, title: "江边散步", tint: sky, location: "黄浦江边")
        // 5/6: sparse（调休）
        timed("demo-may-106", 2026, 5, 7, 18, 30, 20, 0, title: "合唱团排练", tint: sky, location: "文化馆")
        timed("demo-may-106b", 2026, 5, 7, 12, 30, 13, 15, title: "领合唱谱", tint: lilac, location: "文化馆")
        timed("demo-may-107", 2026, 5, 8, 14, 0, 15, 30, title: "一对一 — 职业发展", tint: butter, location: "咖啡实验室")
        add(2026, 5, 9, CalendarEvent(
            id: "demo-may-002", eventIdentifier: nil, day: 9,
            startDate: date(2026, 5, 9, h: 10, min: 0),
            endDate: date(2026, 5, 9, h: 14, min: 0),
            title: "母亲节早午餐", tint: peach, location: "和平饭店", allDay: false
        ))
        timed("demo-may-002b", 2026, 5, 9, 8, 0, 9, 0, title: "买花 + 贺卡", tint: rose, location: "鲜花市场")
        add(2026, 5, 10, CalendarEvent(id: "demo-may-108", eventIdentifier: nil, day: 10, title: "阳台种植日", tint: mint, allDay: true))
        timed("demo-may-108b", 2026, 5, 10, 16, 0, 17, 30, title: "给新花圃浇水", tint: sea, location: "阳台")
        timed("demo-may-109", 2026, 5, 11, 16, 0, 17, 30, title: "牙科 — 复诊", tint: sea, location: "仁爱牙科")
        // 5/12: sparse
        timed("demo-may-111", 2026, 5, 13, 19, 0, 21, 30, title: "看球赛", tint: sky, location: "上海体育场")
        timed("demo-may-112", 2026, 5, 14, 8, 30, 9, 30, title: "绘本朗读志愿", tint: rose, location: "204 教室")
        timed("demo-may-113", 2026, 5, 15, 13, 30, 14, 45, title: "设计系统工作坊", tint: coral, location: "设计实验室")
        timed("demo-may-114", 2026, 5, 16, 10, 30, 11, 45, title: "早市 + 鲜花", tint: peach, location: "农夫市集")
        timed("demo-may-115", 2026, 5, 17, 17, 0, 18, 30, title: "搏击操", tint: butter, location: "健身房")
        timed("demo-may-115b", 2026, 5, 17, 8, 30, 9, 15, title: "拉伸", tint: mint, location: "家")
        // 5/18: sparse
        timed("demo-may-117", 2026, 5, 19, 9, 15, 10, 0, title: "订暑期机票", tint: lilac)
        add(2026, 5, 20, CalendarEvent(id: "demo-may-003", eventIdentifier: nil, day: 20, title: "发布截止 — 日历应用", tint: lilac, allDay: true))
        timed("demo-may-003b", 2026, 5, 20, 10, 0, 10, 45, title: "发布清单 — 最终确认", tint: coral, location: "腾讯会议")
        timed("demo-may-118", 2026, 5, 21, 15, 0, 16, 0, title: "团队复盘", tint: sea, location: "Miro")
        timed("demo-may-118b", 2026, 5, 21, 9, 30, 10, 15, title: "复盘准备 — 记录", tint: butter)
        timed("demo-may-119", 2026, 5, 22, 20, 0, 22, 0, title: "脱口秀现场", tint: peach, location: "笑果工厂")
        add(2026, 5, 23, CalendarEvent(id: "demo-may-120", eventIdentifier: nil, day: 23, title: "周末露营", tint: sky, location: "莫干山", allDay: true))
        timed("demo-may-120b", 2026, 5, 23, 17, 0, 18, 30, title: "篝火 + 烧烤", tint: peach, location: "莫干山")
        // 5/24: sparse
        timed("demo-may-122", 2026, 5, 25, 10, 0, 11, 30, title: "归还露营装备", tint: rose, location: "户外用品店")
        timed("demo-may-123", 2026, 5, 26, 14, 30, 15, 45, title: "心理咨询", tint: mint)
        timed("demo-may-124", 2026, 5, 27, 8, 0, 9, 0, title: "全员会（亚太）", tint: butter, location: "腾讯会议")
        timed("demo-may-125", 2026, 5, 28, 18, 0, 19, 30, title: "约会之夜", tint: lilac, location: "日料 Omakase")
        timed("demo-may-126", 2026, 5, 29, 12, 0, 13, 0, title: "午餐 — 投资人更新", tint: sea, location: "国金中心餐厅")
        timed("demo-may-126b", 2026, 5, 29, 15, 30, 16, 30, title: "投资人跟进邮件", tint: lilac)
        // 5/30: sparse
        add(2026, 5, 31, CalendarEvent(id: "demo-may-127", eventIdentifier: nil, day: 31, title: "月度照片备份", tint: sky, allDay: true))
        timed("demo-may-127b", 2026, 5, 31, 18, 0, 18, 45, title: "检查 iCloud 备份", tint: mint)

        // MARK: 六月
        timed("demo-jun-101", 2026, 6, 1, 9, 30, 10, 30, title: "OKR 复盘", tint: butter, location: "Notion")
        timed("demo-jun-101b", 2026, 6, 1, 14, 0, 15, 0, title: "OKR — 主管确认", tint: sea, location: "腾讯会议")
        timed("demo-jun-102", 2026, 6, 2, 17, 0, 18, 30, title: "孩子游泳课", tint: sea, location: "游泳馆")
        timed("demo-jun-103", 2026, 6, 3, 12, 30, 13, 30, title: "午餐分享 — 隐私", tint: lilac, location: "腾讯会议")
        timed("demo-jun-103b", 2026, 6, 3, 16, 0, 16, 45, title: "隐私合规清单", tint: coral, location: "云盘")
        timed("demo-jun-104", 2026, 6, 4, 19, 30, 21, 0, title: "露天电影", tint: peach, location: "公园露天舞台")
        timed("demo-jun-104b", 2026, 6, 4, 17, 0, 18, 30, title: "野餐垫 + 零食准备", tint: mint, location: "公园")
        add(2026, 6, 5, CalendarEvent(id: "demo-jun-105", eventIdentifier: nil, day: 5, title: "储物间整理", tint: coral, allDay: true))
        timed("demo-jun-105b", 2026, 6, 5, 10, 0, 12, 0, title: "大件垃圾清运", tint: butter, location: "垃圾回收站")
        // 6/6: sparse
        timed("demo-jun-107", 2026, 6, 7, 15, 0, 16, 30, title: "家庭聚餐 — 烤肉", tint: rose, location: "韩式烤肉店")
        timed("demo-jun-108", 2026, 6, 8, 10, 0, 11, 0, title: "值班交接", tint: sky, location: "PagerDuty")
        timed("demo-jun-109", 2026, 6, 9, 13, 0, 14, 30, title: "理财账户检查", tint: butter, location: "券商")
        timed("demo-jun-110", 2026, 6, 10, 18, 0, 19, 15, title: "攀岩", tint: coral, location: "岩馆")
        timed("demo-jun-111", 2026, 6, 11, 11, 30, 12, 45, title: "午餐 — 新 PM 见面", tint: peach, location: "楼顶咖啡馆")
        timed("demo-jun-111b", 2026, 6, 11, 9, 0, 9, 45, title: "预读材料 — PRD v3", tint: lilac, location: "Notion")
        // 6/12: sparse
        add(2026, 6, 13, CalendarEvent(id: "demo-jun-113", eventIdentifier: nil, day: 13, title: "周末旅行 — 千岛湖", tint: sky, location: "湖景民宿", allDay: true))
        timed("demo-jun-113b", 2026, 6, 13, 17, 0, 19, 0, title: "看日落散步 — 湖边", tint: coral, location: "千岛湖")
        timed("demo-jun-114", 2026, 6, 14, 10, 0, 11, 30, title: "退房前早午餐", tint: mint, location: "湖景民宿")
        timed("demo-jun-115", 2026, 6, 15, 16, 0, 17, 0, title: "洗车", tint: sea, location: "洗车店")
        timed("demo-jun-116", 2026, 6, 16, 9, 0, 10, 30, title: "无障碍审查", tint: rose, location: "测试实验室")
        timed("demo-jun-117", 2026, 6, 17, 14, 0, 15, 30, title: "捐赠物品送达", tint: butter, location: "公益回收站")
        timed("demo-jun-117b", 2026, 6, 17, 10, 0, 11, 0, title: "捐赠物品整理", tint: mint, location: "车库")
        // 6/18: sparse
        timed("demo-jun-119", 2026, 6, 19, 12, 0, 13, 0, title: "端午节 — 包粽子", tint: coral, location: "家")
        timed("demo-jun-119b", 2026, 6, 19, 15, 30, 16, 30, title: "龙舟赛观赛", tint: sea, location: "朱家角")
        timed("demo-jun-120", 2026, 6, 20, 8, 45, 10, 15, title: "阳台园艺", tint: peach, location: "阳台")
        add(2026, 6, 21, CalendarEvent(
            id: "demo-jun-001", eventIdentifier: nil, day: 21,
            startDate: date(2026, 6, 21, h: 18, min: 0),
            endDate: date(2026, 6, 21, h: 22, min: 30),
            title: "夏至 — 烧烤聚会", tint: coral, location: "露台", allDay: false
        ))
        timed("demo-jun-121", 2026, 6, 22, 9, 30, 10, 45, title: "供应商安全评审", tint: sea, location: "腾讯会议")
        timed("demo-jun-122", 2026, 6, 23, 17, 30, 18, 45, title: "体检 — 年度", tint: mint, location: "体检中心")
        // 6/24: sparse
        timed("demo-jun-124", 2026, 6, 25, 19, 0, 20, 30, title: "业委会会议", tint: butter, location: "社区活动中心")
        timed("demo-jun-124b", 2026, 6, 25, 12, 0, 13, 0, title: "会议 — 发言提纲准备", tint: lilac)
        timed("demo-jun-125", 2026, 6, 26, 11, 0, 12, 30, title: "季度规划草稿", tint: lilac, location: "Notion / FigJam")
        timed("demo-jun-126", 2026, 6, 27, 15, 0, 16, 30, title: "逛古玩市集", tint: peach, location: "城隍庙")
        add(2026, 6, 28, CalendarEvent(id: "demo-jun-002", eventIdentifier: nil, day: 28, title: "婚礼 — 婷婷 & 浩然", tint: rose, location: "外滩一号", allDay: true))
        timed("demo-jun-002b", 2026, 6, 28, 8, 0, 9, 30, title: "婚礼 — 化妆", tint: peach, location: "酒店")
        timed("demo-jun-127", 2026, 6, 29, 10, 0, 11, 0, title: "婚礼次日早午餐", tint: mint, location: "酒店露台")
        timed("demo-jun-127b", 2026, 6, 29, 14, 0, 15, 30, title: "写感谢卡", tint: butter, location: "酒店大堂")
        // 6/30: sparse

        sortedMap(&out)
        return out
    }
    // swiftlint:enable function_body_length
}
