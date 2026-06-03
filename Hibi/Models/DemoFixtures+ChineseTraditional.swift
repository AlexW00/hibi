import Foundation
import SwiftUI

extension DemoFixtures {
    // swiftlint:disable function_body_length
    static func makeChineseTraditionalEvents() -> EventMap {
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
        add(2026, 2, 1, CalendarEvent(id: "demo-feb-101", eventIdentifier: nil, day: 1, title: "月度預算回顧", tint: butter, allDay: true))
        timed("demo-feb-101b", 2026, 2, 1, 15, 0, 15, 45, title: "季度規劃 — 財務", tint: sea, location: "Google Meet")
        timed("demo-feb-102", 2026, 2, 2, 9, 0, 9, 45, title: "晨間瑜伽", tint: mint, location: "大安瑜伽館", recurring: true)
        add(2026, 2, 3, CalendarEvent(id: "demo-feb-001", eventIdentifier: nil, day: 3, title: "立春", tint: rose, allDay: true))
        timed("demo-feb-001b", 2026, 2, 3, 19, 0, 22, 0, title: "家庭聚餐", tint: lilac, location: "家")
        timed("demo-feb-103", 2026, 2, 4, 12, 0, 12, 30, title: "牙醫 — 洗牙", tint: sea, location: "仁愛牙醫")
        timed("demo-feb-104", 2026, 2, 5, 18, 0, 19, 30, title: "烹飪課: 手工麵", tint: peach, location: "悅食烹飪工作室")
        // 2/6: sparse
        timed("demo-feb-106", 2026, 2, 7, 10, 30, 11, 30, title: "讀書會", tint: sky, location: "誠品書店")
        timed("demo-feb-106b", 2026, 2, 7, 16, 0, 17, 0, title: "採買 + 備菜", tint: butter, location: "city'super")
        timed("demo-feb-107", 2026, 2, 8, 15, 0, 16, 0, title: "孩子足球訓練", tint: coral, location: "台北體育館")
        timed("demo-feb-108", 2026, 2, 9, 8, 30, 9, 15, title: "一對一會談", tint: sea, location: "Google Meet — 會議室A", recurring: true)
        timed("demo-feb-109", 2026, 2, 10, 19, 0, 20, 30, title: "爵士現場", tint: lilac, location: "Blue Note Taipei")
        add(2026, 2, 11, CalendarEvent(id: "demo-feb-110", eventIdentifier: nil, day: 11, title: "公司尾牙", tint: butter, allDay: true))
        timed("demo-feb-110b", 2026, 2, 11, 14, 0, 15, 30, title: "取車 — 保養完成", tint: coral, location: "保養廠")
        // 2/12: sparse
        timed("demo-feb-112", 2026, 2, 13, 17, 30, 18, 30, title: "心理諮商", tint: sky, recurring: true)
        add(2026, 2, 14, CalendarEvent(
            id: "demo-feb-002", eventIdentifier: nil, day: 14,
            startDate: date(2026, 2, 14, h: 10, min: 0),
            endDate: date(2026, 2, 14, h: 12, min: 30),
            title: "情人節 — 早午餐", tint: peach, location: "東區餐廳", allDay: false
        ))
        timed("demo-feb-002b", 2026, 2, 14, 18, 30, 20, 0, title: "黃昏散步 — 河濱", tint: rose, location: "淡水河濱")
        timed("demo-feb-113", 2026, 2, 15, 14, 0, 15, 30, title: "美術館 — 特展", tint: lilac, location: "故宮博物院")
        timed("demo-feb-114", 2026, 2, 16, 11, 0, 12, 0, title: "親師座談", tint: coral, location: "市立小學")
        timed("demo-feb-115", 2026, 2, 17, 16, 0, 17, 0, title: "吉他課", tint: sea)
        // 2/18: sparse
        timed("demo-feb-117", 2026, 2, 19, 20, 0, 22, 30, title: "籃球賽", tint: sky, location: "台北小巨蛋")
        for day in 20 ... 22 {
            add(2026, 2, day, CalendarEvent(id: "demo-feb-onsen-\(day)", eventIdentifier: nil, day: day, title: "春節假期 — 回家", tint: sky, allDay: true))
        }
        timed("demo-feb-onsen21b", 2026, 2, 21, 17, 0, 18, 30, title: "年夜飯 — 團圓", tint: peach, location: "老家")
        timed("demo-feb-118", 2026, 2, 23, 13, 0, 14, 0, title: "午餐 — 投資人", tint: peach, location: "台北 101 餐廳")
        timed("demo-feb-118b", 2026, 2, 23, 16, 30, 17, 30, title: "看辦公室 — 新據點", tint: mint, location: "WeWork 信義")
        // 2/24: sparse
        add(2026, 2, 25, CalendarEvent(id: "demo-feb-120", eventIdentifier: nil, day: 25, title: "綜合所得稅申報準備", tint: rose, allDay: true))
        timed("demo-feb-121", 2026, 2, 26, 8, 0, 8, 30, title: "高鐵去台中", tint: lilac, location: "台北車站")
        timed("demo-feb-122", 2026, 2, 27, 12, 30, 13, 30, title: "設計審查", tint: coral, location: "Figma / 總部")
        add(2026, 2, 28, CalendarEvent(id: "demo-feb-123", eventIdentifier: nil, day: 28, title: "和平紀念日", tint: butter, allDay: true))

        // MARK: 三月
        add(2026, 3, 1, CalendarEvent(id: "demo-mar-101", eventIdentifier: nil, day: 1, title: "春季換季整理", tint: lilac, allDay: true))
        timed("demo-mar-101b", 2026, 3, 1, 14, 0, 15, 0, title: "舊衣捐贈", tint: coral, location: "舊物回收點")
        timed("demo-mar-102", 2026, 3, 2, 9, 30, 10, 30, title: "全員大會", tint: sea, location: "公司禮堂")
        timed("demo-mar-102b", 2026, 3, 2, 15, 0, 16, 0, title: "設計審查 — 追蹤", tint: lilac, location: "Figma")
        add(2026, 3, 3, CalendarEvent(id: "demo-mar-hina", eventIdentifier: nil, day: 3, title: "元宵節", tint: rose, allDay: true))
        timed("demo-mar-103", 2026, 3, 3, 17, 0, 18, 15, title: "搓湯圓", tint: mint, location: "家")
        timed("demo-mar-104", 2026, 3, 4, 12, 0, 13, 0, title: "午餐分享會 — SwiftUI", tint: peach, location: "研發休息區")
        timed("demo-mar-104b", 2026, 3, 4, 18, 0, 19, 0, title: "夜跑 — 大安森林公園", tint: sky, location: "大安森林公園")
        add(2026, 3, 5, CalendarEvent(id: "demo-mar-105", eventIdentifier: nil, day: 5, title: "提交報帳", tint: butter, allDay: true))
        // 3/6: sparse
        timed("demo-mar-107", 2026, 3, 7, 11, 0, 12, 30, title: "和父母早午餐", tint: rose, location: "永康街餐廳")
        add(2026, 3, 8, CalendarEvent(
            id: "demo-mar-001", eventIdentifier: nil, day: 8,
            startDate: date(2026, 3, 8, h: 11, min: 0),
            endDate: date(2026, 3, 8, h: 13, min: 0),
            title: "國際婦女節 — 家庭茶聚", tint: lilac, location: "家", allDay: false
        ))
        timed("demo-mar-108", 2026, 3, 9, 14, 0, 15, 30, title: "街拍散步", tint: coral, location: "赤峰街")
        timed("demo-mar-110", 2026, 3, 10, 8, 0, 9, 0, title: "牙醫 — 定期檢查", tint: sea, location: "仁愛牙醫")
        timed("demo-mar-111", 2026, 3, 11, 19, 30, 21, 0, title: "藝術電影 — 觀影", tint: lilac, location: "真善美劇院")
        // 3/12: sparse
        timed("demo-mar-113", 2026, 3, 13, 16, 0, 17, 30, title: "剪髮", tint: peach, location: "設計沙龍")
        timed("demo-mar-114", 2026, 3, 14, 9, 0, 11, 0, title: "挑選禮物", tint: mint, location: "新光三越")
        timed("demo-mar-114b", 2026, 3, 14, 15, 0, 16, 30, title: "午睡 + 洗衣", tint: butter)
        add(2026, 3, 15, CalendarEvent(
            id: "demo-mar-002", eventIdentifier: nil, day: 15,
            startDate: date(2026, 3, 15, h: 15, min: 30),
            endDate: date(2026, 3, 15, h: 16, min: 30),
            title: "口腔檢查", tint: mint, location: "仁愛牙醫", allDay: false
        ))
        add(2026, 3, 16, CalendarEvent(id: "demo-mar-115", eventIdentifier: nil, day: 16, title: "社區管委會", tint: sky, location: "社區會議室", allDay: true))
        timed("demo-mar-116", 2026, 3, 17, 18, 0, 19, 30, title: "網球課", tint: coral, location: "3 號球場")
        // 3/18: sparse
        timed("demo-mar-119", 2026, 3, 19, 7, 30, 8, 15, title: "飛輪課", tint: rose, location: "World Gym")
        timed("demo-mar-120", 2026, 3, 20, 13, 0, 14, 30, title: "午餐 — 導師咖啡", tint: peach, location: "Louisa 咖啡")
        timed("demo-mar-120b", 2026, 3, 20, 17, 0, 18, 0, title: "程式碼審查 — 日曆小工具", tint: sea, location: "Google Meet")
        add(2026, 3, 21, CalendarEvent(id: "demo-mar-121", eventIdentifier: nil, day: 21, title: "春分 — 陽明山健走", tint: mint, location: "陽明山", allDay: true))
        timed("demo-mar-122", 2026, 3, 22, 15, 0, 16, 30, title: "孩子生日派對", tint: lilac, location: "兒童樂園")
        timed("demo-mar-122b", 2026, 3, 22, 10, 0, 11, 30, title: "派對準備（佈置）", tint: sky, location: "兒童樂園")
        timed("demo-mar-123", 2026, 3, 23, 9, 30, 10, 30, title: "法務審查 — 合約", tint: butter, location: "WeWork 松菸")
        // 3/24: sparse
        timed("demo-mar-125", 2026, 3, 25, 11, 30, 12, 30, title: "辦公時間", tint: coral, location: "Slack 通話")
        timed("demo-mar-126", 2026, 3, 26, 17, 0, 18, 0, title: "遛狗訓練課", tint: sea, location: "大安森林公園")
        timed("demo-mar-127", 2026, 3, 27, 8, 45, 9, 30, title: "送孩子上學", tint: peach)
        add(2026, 3, 28, CalendarEvent(id: "demo-mar-003", eventIdentifier: nil, day: 28, title: "大掃除 — 春季煥新", tint: butter, allDay: true))
        timed("demo-mar-128", 2026, 3, 29, 14, 0, 15, 0, title: "公益路跑 — 領號碼布", tint: rose, location: "台北田徑場")
        // 3/30: sparse
        add(2026, 3, 31, CalendarEvent(id: "demo-mar-130", eventIdentifier: nil, day: 31, title: "提交 Q1 總結", tint: sky, allDay: true))

        // MARK: 四月（充實 — 主要演示月）
        add(2026, 4, 1, CalendarEvent(id: "demo-apr-101", eventIdentifier: nil, day: 1, title: "新財年啟動", tint: butter, allDay: true))
        timed("demo-apr-101b", 2026, 4, 1, 11, 0, 11, 45, title: "新同事歡迎午餐", tint: lilac, location: "員工餐廳")
        timed("demo-apr-102", 2026, 4, 2, 9, 0, 10, 0, title: "晨會", tint: sea, location: "Google Meet")
        timed("demo-apr-103", 2026, 4, 2, 15, 30, 16, 30, title: "和鄰居阿嬤喝茶", tint: peach, location: "院子")
        add(2026, 4, 3, CalendarEvent(
            id: "demo-apr-001", eventIdentifier: nil, day: 3,
            startDate: date(2026, 4, 3, h: 10, min: 0),
            endDate: date(2026, 4, 3, h: 11, min: 30),
            title: "團隊晨會 & 路線圖", tint: sea, location: "Google Meet", allDay: false
        ))
        timed("demo-apr-001b", 2026, 4, 3, 14, 0, 15, 30, title: "路線圖 — 利害關係人問答", tint: lilac, location: "Google Meet")
        timed("demo-apr-104", 2026, 4, 4, 11, 0, 12, 30, title: "賞櫻早午餐", tint: rose, location: "陽明山")
        timed("demo-apr-104b", 2026, 4, 4, 16, 0, 17, 30, title: "賞櫻 — 佔位", tint: mint, location: "陽明山")
        add(2026, 4, 5, CalendarEvent(
            id: "demo-apr-002", eventIdentifier: nil, day: 5,
            startDate: date(2026, 4, 5, h: 19, min: 30),
            endDate: date(2026, 4, 5, h: 22, min: 0),
            title: "古典音樂會", tint: lilac, location: "國家音樂廳", allDay: false
        ))
        timed("demo-apr-005b", 2026, 4, 5, 10, 0, 11, 30, title: "看電影 — 全家", tint: butter, location: "威秀影城")
        // 4/6: sparse
        timed("demo-apr-106", 2026, 4, 7, 18, 0, 19, 30, title: "足球補訓", tint: coral, location: "台北體育館")
        timed("demo-apr-106b", 2026, 4, 7, 8, 0, 8, 45, title: "整理信件 — 專注時間", tint: sea)
        timed("demo-apr-107", 2026, 4, 8, 12, 0, 12, 45, title: "午間散步", tint: sky)
        timed("demo-apr-108", 2026, 4, 9, 14, 0, 15, 30, title: "使用者研究", tint: lilac, location: "2 號實驗室")
        timed("demo-apr-108b", 2026, 4, 9, 18, 0, 19, 0, title: "原型修改 — 交接", tint: peach, location: "2 號實驗室")
        for day in 10 ... 11 {
            add(2026, 4, day, CalendarEvent(id: "demo-apr-tech-\(day)", eventIdentifier: nil, day: day, title: "技術大會", tint: sky, allDay: true))
        }
        timed("demo-apr-tech11b", 2026, 4, 11, 17, 0, 18, 30, title: "大會 — 撤展", tint: coral, location: "南港展覽館")
        // 4/12: sparse
        timed("demo-apr-109", 2026, 4, 13, 10, 0, 11, 0, title: "績效評估 — 啟動", tint: butter, location: "HR 系統")
        timed("demo-apr-109b", 2026, 4, 13, 14, 30, 15, 45, title: "一對一 — 設計主管", tint: lilac, location: "靜音室")
        timed("demo-apr-110", 2026, 4, 14, 19, 0, 20, 30, title: "相聲專場", tint: peach, location: "相聲瓦舍")
        timed("demo-apr-111", 2026, 4, 15, 9, 30, 10, 45, title: "架構審查", tint: sea, location: "作戰室")
        timed("demo-apr-111b", 2026, 4, 15, 12, 0, 13, 0, title: "午餐 — 平台團隊", tint: peach, location: "園區咖啡館")
        timed("demo-apr-112", 2026, 4, 16, 16, 0, 17, 0, title: "還租車", tint: coral, location: "機場")
        timed("demo-apr-112b", 2026, 4, 16, 10, 30, 11, 30, title: "航班延誤緩衝", tint: butter, location: "貴賓室")
        timed("demo-apr-113", 2026, 4, 17, 11, 30, 12, 30, title: "皮膚科", tint: mint, location: "皮膚科診所")

        // 2026-04-18 (SampleData「今天」)
        add(2026, 4, 18, CalendarEvent(
            id: "demo-apr-today-001", eventIdentifier: nil, day: 18,
            startDate: date(2026, 4, 18, h: 8, min: 0),
            endDate: date(2026, 4, 18, h: 9, min: 30),
            title: "早餐 — 和美琪", tint: peach, location: "麥田麵包坊", allDay: false
        ))
        timed("demo-apr-today-progress", 2026, 4, 18, 10, 0, 20, 0, title: "App Store 收尾 — 專注時段", tint: sea, location: "居家辦公室", recurring: true)
        add(2026, 4, 18, CalendarEvent(
            id: "demo-apr-today-002", eventIdentifier: nil, day: 18,
            startDate: date(2026, 4, 18, h: 12, min: 30),
            endDate: date(2026, 4, 18, h: 13, min: 45),
            title: "團隊午餐", tint: mint, location: "義式餐廳", allDay: false,
            isRecurring: true
        ))
        add(2026, 4, 18, CalendarEvent(id: "demo-apr-today-003", eventIdentifier: nil, day: 18, title: "家庭聚會（整天）", tint: rose, location: "爺爺奶奶家", allDay: true))
        add(2026, 4, 18, CalendarEvent(
            id: "demo-apr-today-004", eventIdentifier: nil, day: 18,
            startDate: date(2026, 4, 18, h: 20, min: 15),
            endDate: date(2026, 4, 18, h: 23, min: 15),
            title: "電影:沙丘 2", tint: coral, location: "威秀 IMAX", allDay: false
        ))

        timed("demo-apr-114", 2026, 4, 19, 10, 0, 11, 30, title: "週日慢跑", tint: mint, location: "大安森林公園")
        timed("demo-apr-114b", 2026, 4, 19, 15, 0, 17, 0, title: "備菜 + 播客", tint: sky)
        timed("demo-apr-115", 2026, 4, 20, 13, 0, 14, 0, title: "薪資審核", tint: butter, location: "財務系統")
        timed("demo-apr-116", 2026, 4, 21, 17, 30, 18, 45, title: "網球雙打", tint: sky, location: "球場")
        timed("demo-apr-117", 2026, 4, 22, 8, 0, 8, 45, title: "航班報到", tint: lilac)
        timed("demo-apr-118", 2026, 4, 23, 15, 0, 16, 30, title: "播客錄製", tint: peach, location: "居家錄音室")
        timed("demo-apr-118b", 2026, 4, 23, 19, 0, 20, 0, title: "播客初剪", tint: lilac, location: "居家錄音室")
        // 4/24: sparse
        add(2026, 4, 25, CalendarEvent(id: "demo-apr-004", eventIdentifier: nil, day: 25, title: "一日遊 — 九份", tint: sea, allDay: true))
        timed("demo-apr-004b", 2026, 4, 25, 8, 30, 9, 15, title: "便當 + 準備", tint: butter)
        timed("demo-apr-120", 2026, 4, 26, 14, 0, 15, 0, title: "換盆派對", tint: rose, location: "陽台")
        timed("demo-apr-121", 2026, 4, 27, 9, 0, 10, 0, title: "資安訓練（年度）", tint: coral, location: "線上課程")
        timed("demo-apr-122", 2026, 4, 28, 18, 0, 19, 15, title: "烘焙課: 鄉村麵包", tint: lilac, location: "烘焙工作室")
        add(2026, 4, 29, CalendarEvent(id: "demo-apr-showa", eventIdentifier: nil, day: 29, title: "團隊建設日", tint: butter, allDay: true))
        timed("demo-apr-123", 2026, 4, 29, 11, 0, 12, 0, title: "廠商展示 — 分析工具", tint: sea, location: "Google Meet")
        // 4/30: sparse

        // MARK: 五月
        add(2026, 5, 1, CalendarEvent(id: "demo-may-001", eventIdentifier: nil, day: 1, title: "勞動節", tint: rose, allDay: true))
        timed("demo-may-001b", 2026, 5, 1, 8, 30, 9, 30, title: "社區志工準備", tint: sea, location: "里民活動中心")
        timed("demo-may-101", 2026, 5, 2, 10, 0, 12, 0, title: "二手市集準備", tint: peach, location: "停車場")
        timed("demo-may-101b", 2026, 5, 2, 14, 0, 16, 0, title: "二手市集收攤", tint: butter, location: "停車場")
        add(2026, 5, 3, CalendarEvent(id: "demo-may-kenpo", eventIdentifier: nil, day: 3, title: "連假 — 近郊小旅行", tint: lilac, allDay: true))
        timed("demo-may-102", 2026, 5, 3, 15, 30, 17, 0, title: "鋼琴發表會", tint: sky, location: "音樂教室")
        add(2026, 5, 4, CalendarEvent(id: "demo-may-midori", eventIdentifier: nil, day: 4, title: "踏青 — 郊外", tint: mint, allDay: true))
        timed("demo-may-103", 2026, 5, 4, 9, 0, 10, 30, title: "董事會準備", tint: sea, location: "B 會議室")
        add(2026, 5, 5, CalendarEvent(id: "demo-may-kodomo", eventIdentifier: nil, day: 5, title: "立夏", tint: coral, allDay: true))
        timed("demo-may-104", 2026, 5, 5, 12, 15, 13, 0, title: "立夏煮蛋", tint: peach, location: "家")
        timed("demo-may-104b", 2026, 5, 5, 16, 0, 17, 0, title: "河邊散步", tint: sky, location: "淡水河邊")
        // 5/6: sparse（補假）
        timed("demo-may-106", 2026, 5, 7, 18, 30, 20, 0, title: "合唱團排練", tint: sky, location: "社區活動中心")
        timed("demo-may-106b", 2026, 5, 7, 12, 30, 13, 15, title: "領合唱譜", tint: lilac, location: "社區活動中心")
        timed("demo-may-107", 2026, 5, 8, 14, 0, 15, 30, title: "一對一 — 職涯發展", tint: butter, location: "咖啡實驗室")
        add(2026, 5, 9, CalendarEvent(
            id: "demo-may-002", eventIdentifier: nil, day: 9,
            startDate: date(2026, 5, 9, h: 10, min: 0),
            endDate: date(2026, 5, 9, h: 14, min: 0),
            title: "母親節早午餐", tint: peach, location: "君悅酒店", allDay: false
        ))
        timed("demo-may-002b", 2026, 5, 9, 8, 0, 9, 0, title: "買花 + 卡片", tint: rose, location: "建國花市")
        add(2026, 5, 10, CalendarEvent(id: "demo-may-108", eventIdentifier: nil, day: 10, title: "陽台種植日", tint: mint, allDay: true))
        timed("demo-may-108b", 2026, 5, 10, 16, 0, 17, 30, title: "幫新花圃澆水", tint: sea, location: "陽台")
        timed("demo-may-109", 2026, 5, 11, 16, 0, 17, 30, title: "牙醫 — 回診", tint: sea, location: "仁愛牙醫")
        // 5/12: sparse
        timed("demo-may-111", 2026, 5, 13, 19, 0, 21, 30, title: "看棒球賽", tint: sky, location: "台北大巨蛋")
        timed("demo-may-112", 2026, 5, 14, 8, 30, 9, 30, title: "繪本朗讀志工", tint: rose, location: "204 教室")
        timed("demo-may-113", 2026, 5, 15, 13, 30, 14, 45, title: "設計系統工作坊", tint: coral, location: "設計實驗室")
        timed("demo-may-114", 2026, 5, 16, 10, 30, 11, 45, title: "早市 + 鮮花", tint: peach, location: "農夫市集")
        timed("demo-may-115", 2026, 5, 17, 17, 0, 18, 30, title: "拳擊有氧", tint: butter, location: "健身房")
        timed("demo-may-115b", 2026, 5, 17, 8, 30, 9, 15, title: "伸展", tint: mint, location: "家")
        // 5/18: sparse
        timed("demo-may-117", 2026, 5, 19, 9, 15, 10, 0, title: "訂暑期機票", tint: lilac)
        add(2026, 5, 20, CalendarEvent(id: "demo-may-003", eventIdentifier: nil, day: 20, title: "發布截止 — 日曆應用", tint: lilac, allDay: true))
        timed("demo-may-003b", 2026, 5, 20, 10, 0, 10, 45, title: "發布清單 — 最終確認", tint: coral, location: "Google Meet")
        timed("demo-may-118", 2026, 5, 21, 15, 0, 16, 0, title: "團隊回顧", tint: sea, location: "Miro")
        timed("demo-may-118b", 2026, 5, 21, 9, 30, 10, 15, title: "回顧準備 — 筆記", tint: butter)
        timed("demo-may-119", 2026, 5, 22, 20, 0, 22, 0, title: "脫口秀現場", tint: peach, location: "卡米地喜劇俱樂部")
        add(2026, 5, 23, CalendarEvent(id: "demo-may-120", eventIdentifier: nil, day: 23, title: "週末露營", tint: sky, location: "清境", allDay: true))
        timed("demo-may-120b", 2026, 5, 23, 17, 0, 18, 30, title: "營火 + 烤肉", tint: peach, location: "清境")
        // 5/24: sparse
        timed("demo-may-122", 2026, 5, 25, 10, 0, 11, 30, title: "歸還露營裝備", tint: rose, location: "戶外用品店")
        timed("demo-may-123", 2026, 5, 26, 14, 30, 15, 45, title: "心理諮商", tint: mint)
        timed("demo-may-124", 2026, 5, 27, 8, 0, 9, 0, title: "全員會議（亞太）", tint: butter, location: "Google Meet")
        timed("demo-may-125", 2026, 5, 28, 18, 0, 19, 30, title: "約會之夜", tint: lilac, location: "日料 Omakase")
        timed("demo-may-126", 2026, 5, 29, 12, 0, 13, 0, title: "午餐 — 投資人更新", tint: sea, location: "台北 101 餐廳")
        timed("demo-may-126b", 2026, 5, 29, 15, 30, 16, 30, title: "投資人追蹤信", tint: lilac)
        // 5/30: sparse
        add(2026, 5, 31, CalendarEvent(id: "demo-may-127", eventIdentifier: nil, day: 31, title: "月度照片備份", tint: sky, allDay: true))
        timed("demo-may-127b", 2026, 5, 31, 18, 0, 18, 45, title: "確認 iCloud 備份", tint: mint)

        // MARK: 六月
        timed("demo-jun-101", 2026, 6, 1, 9, 30, 10, 30, title: "OKR 回顧", tint: butter, location: "Notion")
        timed("demo-jun-101b", 2026, 6, 1, 14, 0, 15, 0, title: "OKR — 主管確認", tint: sea, location: "Google Meet")
        timed("demo-jun-102", 2026, 6, 2, 17, 0, 18, 30, title: "孩子游泳課", tint: sea, location: "游泳池")
        timed("demo-jun-103", 2026, 6, 3, 12, 30, 13, 30, title: "午餐分享 — 隱私", tint: lilac, location: "Google Meet")
        timed("demo-jun-103b", 2026, 6, 3, 16, 0, 16, 45, title: "隱私合規清單", tint: coral, location: "雲端硬碟")
        timed("demo-jun-104", 2026, 6, 4, 19, 30, 21, 0, title: "露天電影", tint: peach, location: "公園露天舞台")
        timed("demo-jun-104b", 2026, 6, 4, 17, 0, 18, 30, title: "野餐墊 + 點心準備", tint: mint, location: "公園")
        add(2026, 6, 5, CalendarEvent(id: "demo-jun-105", eventIdentifier: nil, day: 5, title: "儲藏室整理", tint: coral, allDay: true))
        timed("demo-jun-105b", 2026, 6, 5, 10, 0, 12, 0, title: "大型垃圾清運", tint: butter, location: "資源回收站")
        // 6/6: sparse
        timed("demo-jun-107", 2026, 6, 7, 15, 0, 16, 30, title: "家庭聚餐 — 烤肉", tint: rose, location: "韓式烤肉")
        timed("demo-jun-108", 2026, 6, 8, 10, 0, 11, 0, title: "值班交接", tint: sky, location: "PagerDuty")
        timed("demo-jun-109", 2026, 6, 9, 13, 0, 14, 30, title: "理財帳戶檢視", tint: butter, location: "券商")
        timed("demo-jun-110", 2026, 6, 10, 18, 0, 19, 15, title: "攀岩", tint: coral, location: "攀岩館")
        timed("demo-jun-111", 2026, 6, 11, 11, 30, 12, 45, title: "午餐 — 新 PM 見面", tint: peach, location: "頂樓咖啡館")
        timed("demo-jun-111b", 2026, 6, 11, 9, 0, 9, 45, title: "預讀資料 — PRD v3", tint: lilac, location: "Notion")
        // 6/12: sparse
        add(2026, 6, 13, CalendarEvent(id: "demo-jun-113", eventIdentifier: nil, day: 13, title: "週末旅行 — 日月潭", tint: sky, location: "湖景民宿", allDay: true))
        timed("demo-jun-113b", 2026, 6, 13, 17, 0, 19, 0, title: "看日落散步 — 湖邊", tint: coral, location: "日月潭")
        timed("demo-jun-114", 2026, 6, 14, 10, 0, 11, 30, title: "退房前早午餐", tint: mint, location: "湖景民宿")
        timed("demo-jun-115", 2026, 6, 15, 16, 0, 17, 0, title: "洗車", tint: sea, location: "洗車場")
        timed("demo-jun-116", 2026, 6, 16, 9, 0, 10, 30, title: "無障礙稽核", tint: rose, location: "測試實驗室")
        timed("demo-jun-117", 2026, 6, 17, 14, 0, 15, 30, title: "捐贈物品送達", tint: butter, location: "公益回收站")
        timed("demo-jun-117b", 2026, 6, 17, 10, 0, 11, 0, title: "捐贈物品分類", tint: mint, location: "車庫")
        // 6/18: sparse
        timed("demo-jun-119", 2026, 6, 19, 12, 0, 13, 0, title: "端午節 — 包粽子", tint: coral, location: "家")
        timed("demo-jun-119b", 2026, 6, 19, 15, 30, 16, 30, title: "龍舟賽觀賽", tint: sea, location: "大佳河濱")
        timed("demo-jun-120", 2026, 6, 20, 8, 45, 10, 15, title: "陽台園藝", tint: peach, location: "陽台")
        add(2026, 6, 21, CalendarEvent(
            id: "demo-jun-001", eventIdentifier: nil, day: 21,
            startDate: date(2026, 6, 21, h: 18, min: 0),
            endDate: date(2026, 6, 21, h: 22, min: 30),
            title: "夏至 — 烤肉聚會", tint: coral, location: "露台", allDay: false
        ))
        timed("demo-jun-121", 2026, 6, 22, 9, 30, 10, 45, title: "廠商資安審查", tint: sea, location: "Google Meet")
        timed("demo-jun-122", 2026, 6, 23, 17, 30, 18, 45, title: "健康檢查 — 年度", tint: mint, location: "健檢中心")
        // 6/24: sparse
        timed("demo-jun-124", 2026, 6, 25, 19, 0, 20, 30, title: "社區大會", tint: butter, location: "里民活動中心")
        timed("demo-jun-124b", 2026, 6, 25, 12, 0, 13, 0, title: "大會 — 發言提綱準備", tint: lilac)
        timed("demo-jun-125", 2026, 6, 26, 11, 0, 12, 30, title: "季度規劃草稿", tint: lilac, location: "Notion / FigJam")
        timed("demo-jun-126", 2026, 6, 27, 15, 0, 16, 30, title: "逛古物市集", tint: peach, location: "華山文創市集")
        add(2026, 6, 28, CalendarEvent(id: "demo-jun-002", eventIdentifier: nil, day: 28, title: "婚禮 — 婷婷 & 浩然", tint: rose, location: "晶華酒店", allDay: true))
        timed("demo-jun-002b", 2026, 6, 28, 8, 0, 9, 30, title: "婚禮 — 新娘秘書", tint: peach, location: "酒店")
        timed("demo-jun-127", 2026, 6, 29, 10, 0, 11, 0, title: "婚禮次日早午餐", tint: mint, location: "酒店露台")
        timed("demo-jun-127b", 2026, 6, 29, 14, 0, 15, 30, title: "寫感謝卡", tint: butter, location: "酒店大廳")
        // 6/30: sparse

        sortedMap(&out)
        return out
    }
    // swiftlint:enable function_body_length
}
