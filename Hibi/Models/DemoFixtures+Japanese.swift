import Foundation
import SwiftUI

extension DemoFixtures {
    // swiftlint:disable function_body_length
    static func makeJapaneseEvents() -> EventMap {
        var out: EventMap = [:]

        func add(_ y: Int, _ m: Int, _ day: Int, _ event: CalendarEvent) {
            let key = MonthKey(year: y, month: m)
            out[key, default: [:]][day, default: []].append(event)
        }

        func timed(
            _ id: String,
            _ y: Int, _ m: Int, _ day: Int,
            _ h1: Int, _ m1: Int, _ h2: Int, _ m2: Int,
            title: String, tint: Color, location: String? = nil
        ) {
            let s = date(y, m, day, h: h1, min: m1)
            let e = date(y, m, day, h: h2, min: m2)
            add(y, m, day, CalendarEvent(
                id: id, eventIdentifier: nil, day: day,
                startDate: s, endDate: e,
                title: title, tint: tint, location: location, allDay: false
            ))
        }

        // MARK: 2月
        add(2026, 2, 1, CalendarEvent(id: "demo-feb-101", eventIdentifier: nil, day: 1, title: "月次予算レビュー", tint: butter, allDay: true))
        timed("demo-feb-101b", 2026, 2, 1, 15, 0, 15, 45, title: "四半期計画 — 経理", tint: sea, location: "Zoom")
        timed("demo-feb-102", 2026, 2, 2, 9, 0, 9, 45, title: "朝ヨガ", tint: mint, location: "スタジオ青山")
        add(2026, 2, 3, CalendarEvent(id: "demo-feb-001", eventIdentifier: nil, day: 3, title: "節分 — 豆まき", tint: rose, allDay: true))
        timed("demo-feb-001b", 2026, 2, 3, 19, 0, 22, 0, title: "恵方巻きディナー", tint: lilac, location: "自宅")
        timed("demo-feb-103", 2026, 2, 4, 12, 0, 12, 30, title: "歯医者 — クリーニング", tint: sea, location: "田中歯科")
        timed("demo-feb-104", 2026, 2, 5, 18, 0, 19, 30, title: "料理教室: 手打ちうどん", tint: peach, location: "ABC Cooking Studio")
        // 2/6: sparse
        timed("demo-feb-106", 2026, 2, 7, 10, 30, 11, 30, title: "読書会", tint: sky, location: "蔦屋書店 代官山")
        timed("demo-feb-106b", 2026, 2, 7, 16, 0, 17, 0, title: "買い出し + 作り置き", tint: butter, location: "成城石井")
        timed("demo-feb-107", 2026, 2, 8, 15, 0, 16, 0, title: "子どものサッカー練習", tint: coral, location: "駒沢グラウンド")
        timed("demo-feb-108", 2026, 2, 9, 8, 30, 9, 15, title: "1on1 ミーティング", tint: sea, location: "Meet — 会議室A")
        timed("demo-feb-109", 2026, 2, 10, 19, 0, 20, 30, title: "ジャズライブ", tint: lilac, location: "Blue Note 東京")
        add(2026, 2, 11, CalendarEvent(id: "demo-feb-110", eventIdentifier: nil, day: 11, title: "建国記念の日", tint: butter, allDay: true))
        timed("demo-feb-110b", 2026, 2, 11, 14, 0, 15, 30, title: "車の点検受け取り", tint: coral, location: "オートバックス")
        // 2/12: sparse
        timed("demo-feb-112", 2026, 2, 13, 17, 30, 18, 30, title: "カウンセリング", tint: sky)
        add(2026, 2, 14, CalendarEvent(
            id: "demo-feb-002", eventIdentifier: nil, day: 14,
            startDate: date(2026, 2, 14, h: 10, min: 0),
            endDate: date(2026, 2, 14, h: 12, min: 30),
            title: "バレンタイン — ブランチ", tint: peach, location: "bills 表参道", allDay: false
        ))
        timed("demo-feb-002b", 2026, 2, 14, 18, 30, 20, 0, title: "夕暮れ散歩 — 隅田川", tint: rose, location: "隅田川テラス")
        timed("demo-feb-113", 2026, 2, 15, 14, 0, 15, 30, title: "美術館 — 浮世絵展", tint: lilac, location: "国立新美術館")
        timed("demo-feb-114", 2026, 2, 16, 11, 0, 12, 0, title: "保護者面談", tint: coral, location: "区立小学校")
        timed("demo-feb-115", 2026, 2, 17, 16, 0, 17, 0, title: "ギターレッスン", tint: sea)
        // 2/18: sparse
        timed("demo-feb-117", 2026, 2, 19, 20, 0, 22, 30, title: "バスケ観戦", tint: sky, location: "代々木体育館")
        for day in 20 ... 22 {
            add(2026, 2, day, CalendarEvent(id: "demo-feb-onsen-\(day)", eventIdentifier: nil, day: day, title: "温泉旅行 — 箱根", tint: sky, allDay: true))
        }
        timed("demo-feb-onsen21b", 2026, 2, 21, 17, 0, 18, 30, title: "露天風呂 + 懐石ディナー", tint: peach, location: "箱根旅館")
        timed("demo-feb-118", 2026, 2, 23, 13, 0, 14, 0, title: "ランチ — 投資家", tint: peach, location: "丸の内レストラン")
        timed("demo-feb-118b", 2026, 2, 23, 16, 30, 17, 30, title: "内見 — 新オフィス", tint: mint, location: "WeWork 渋谷")
        // 2/24: sparse
        add(2026, 2, 25, CalendarEvent(id: "demo-feb-120", eventIdentifier: nil, day: 25, title: "確定申告の準備", tint: rose, allDay: true))
        timed("demo-feb-121", 2026, 2, 26, 8, 0, 8, 30, title: "大阪へ新幹線", tint: lilac, location: "東京駅")
        timed("demo-feb-122", 2026, 2, 27, 12, 30, 13, 30, title: "デザインレビュー", tint: coral, location: "Figma / 本社")
        add(2026, 2, 28, CalendarEvent(id: "demo-feb-123", eventIdentifier: nil, day: 28, title: "冬物セール最終日", tint: butter, allDay: true))

        // MARK: 3月
        add(2026, 3, 1, CalendarEvent(id: "demo-mar-101", eventIdentifier: nil, day: 1, title: "春の衣替え", tint: lilac, allDay: true))
        timed("demo-mar-101b", 2026, 3, 1, 14, 0, 15, 0, title: "古着を寄付", tint: coral, location: "リサイクルショップ")
        timed("demo-mar-102", 2026, 3, 2, 9, 30, 10, 30, title: "全社ミーティング", tint: sea, location: "タウンホール")
        timed("demo-mar-102b", 2026, 3, 2, 15, 0, 16, 0, title: "デザインレビュー — フォローアップ", tint: lilac, location: "Figma")
        add(2026, 3, 3, CalendarEvent(id: "demo-mar-hina", eventIdentifier: nil, day: 3, title: "ひな祭り", tint: rose, allDay: true))
        timed("demo-mar-103", 2026, 3, 3, 17, 0, 18, 15, title: "ちらし寿司づくり", tint: mint, location: "自宅")
        timed("demo-mar-104", 2026, 3, 4, 12, 0, 13, 0, title: "ランチ勉強会 — SwiftUI", tint: peach, location: "開発ラウンジ")
        timed("demo-mar-104b", 2026, 3, 4, 18, 0, 19, 0, title: "ランニング — 皇居一周", tint: sky, location: "皇居")
        add(2026, 3, 5, CalendarEvent(id: "demo-mar-105", eventIdentifier: nil, day: 5, title: "経費精算提出", tint: butter, allDay: true))
        // 3/6: sparse
        timed("demo-mar-107", 2026, 3, 7, 11, 0, 12, 30, title: "両親とブランチ", tint: rose, location: "紀尾井町レストラン")
        add(2026, 3, 8, CalendarEvent(
            id: "demo-mar-001", eventIdentifier: nil, day: 8,
            startDate: date(2026, 3, 8, h: 11, min: 0),
            endDate: date(2026, 3, 8, h: 13, min: 0),
            title: "国際女性デー — ファミリーお茶会", tint: lilac, location: "自宅", allDay: false
        ))
        timed("demo-mar-108", 2026, 3, 9, 14, 0, 15, 30, title: "写真散歩", tint: coral, location: "谷中銀座")
        timed("demo-mar-110", 2026, 3, 10, 8, 0, 9, 0, title: "歯医者 — 定期検診", tint: sea, location: "田中歯科")
        timed("demo-mar-111", 2026, 3, 11, 19, 30, 21, 0, title: "ミニシアター — 映画鑑賞", tint: lilac, location: "下北沢トリウッド")
        // 3/12: sparse
        timed("demo-mar-113", 2026, 3, 13, 16, 0, 17, 30, title: "美容院", tint: peach, location: "ALBUM 原宿")
        timed("demo-mar-114", 2026, 3, 14, 9, 0, 11, 0, title: "ホワイトデー — お返し選び", tint: mint, location: "伊勢丹")
        timed("demo-mar-114b", 2026, 3, 14, 15, 0, 16, 30, title: "昼寝 + 洗濯", tint: butter)
        add(2026, 3, 15, CalendarEvent(
            id: "demo-mar-002", eventIdentifier: nil, day: 15,
            startDate: date(2026, 3, 15, h: 15, min: 30),
            endDate: date(2026, 3, 15, h: 16, min: 30),
            title: "歯科検診", tint: mint, location: "田中歯科", allDay: false
        ))
        add(2026, 3, 16, CalendarEvent(id: "demo-mar-115", eventIdentifier: nil, day: 16, title: "マンション理事会", tint: sky, location: "集会室", allDay: true))
        timed("demo-mar-116", 2026, 3, 17, 18, 0, 19, 30, title: "テニススクール", tint: coral, location: "コート3")
        // 3/18: sparse
        timed("demo-mar-119", 2026, 3, 19, 7, 30, 8, 15, title: "スピンクラス", tint: rose, location: "エニタイムフィットネス")
        timed("demo-mar-120", 2026, 3, 20, 13, 0, 14, 30, title: "ランチ — メンターコーヒー", tint: peach, location: "丸山珈琲")
        timed("demo-mar-120b", 2026, 3, 20, 17, 0, 18, 0, title: "コードレビュー — カレンダーWidget", tint: sea, location: "Zoom")
        add(2026, 3, 21, CalendarEvent(id: "demo-mar-121", eventIdentifier: nil, day: 21, title: "春分の日 — 高尾山ハイキング", tint: mint, location: "高尾山", allDay: true))
        timed("demo-mar-122", 2026, 3, 22, 15, 0, 16, 30, title: "子どもの誕生日パーティー", tint: lilac, location: "キッズパーク")
        timed("demo-mar-122b", 2026, 3, 22, 10, 0, 11, 30, title: "パーティー準備（飾り付け）", tint: sky, location: "キッズパーク")
        timed("demo-mar-123", 2026, 3, 23, 9, 30, 10, 30, title: "法務レビュー — 契約書", tint: butter, location: "WeWork 六本木")
        // 3/24: sparse
        timed("demo-mar-125", 2026, 3, 25, 11, 30, 12, 30, title: "オフィスアワー", tint: coral, location: "Slack ハドル")
        timed("demo-mar-126", 2026, 3, 26, 17, 0, 18, 0, title: "犬のしつけ教室", tint: sea, location: "代々木公園")
        timed("demo-mar-127", 2026, 3, 27, 8, 45, 9, 30, title: "子ども送り当番", tint: peach)
        add(2026, 3, 28, CalendarEvent(id: "demo-mar-003", eventIdentifier: nil, day: 28, title: "大掃除 — 春の模様替え", tint: butter, allDay: true))
        timed("demo-mar-128", 2026, 3, 29, 14, 0, 15, 0, title: "チャリティラン — ゼッケン受取", tint: rose, location: "国立競技場")
        // 3/30: sparse
        add(2026, 3, 31, CalendarEvent(id: "demo-mar-130", eventIdentifier: nil, day: 31, title: "Q1まとめメモ提出", tint: sky, allDay: true))

        // MARK: 4月 (充実 — メインデモ月)
        add(2026, 4, 1, CalendarEvent(id: "demo-apr-101", eventIdentifier: nil, day: 1, title: "新年度スタート", tint: butter, allDay: true))
        timed("demo-apr-101b", 2026, 4, 1, 11, 0, 11, 45, title: "新メンバー歓迎ランチ", tint: lilac, location: "社食")
        timed("demo-apr-102", 2026, 4, 2, 9, 0, 10, 0, title: "朝会", tint: sea, location: "Zoom")
        timed("demo-apr-103", 2026, 4, 2, 15, 30, 16, 30, title: "近所のおばあちゃんとお茶", tint: peach, location: "縁側")
        add(2026, 4, 3, CalendarEvent(
            id: "demo-apr-001", eventIdentifier: nil, day: 3,
            startDate: date(2026, 4, 3, h: 10, min: 0),
            endDate: date(2026, 4, 3, h: 11, min: 30),
            title: "チーム朝会 & ロードマップ", tint: sea, location: "Zoom", allDay: false
        ))
        timed("demo-apr-001b", 2026, 4, 3, 14, 0, 15, 30, title: "ロードマップ — ステークホルダーQ&A", tint: lilac, location: "Zoom")
        timed("demo-apr-104", 2026, 4, 4, 11, 0, 12, 30, title: "お花見ブランチ", tint: rose, location: "目黒川沿い")
        timed("demo-apr-104b", 2026, 4, 4, 16, 0, 17, 30, title: "花見 — 場所取り", tint: mint, location: "上野公園")
        add(2026, 4, 5, CalendarEvent(
            id: "demo-apr-002", eventIdentifier: nil, day: 5,
            startDate: date(2026, 4, 5, h: 19, min: 30),
            endDate: date(2026, 4, 5, h: 22, min: 0),
            title: "クラシックコンサート", tint: lilac, location: "サントリーホール", allDay: false
        ))
        timed("demo-apr-005b", 2026, 4, 5, 10, 0, 11, 30, title: "映画 — 家族で", tint: butter, location: "TOHOシネマズ")
        // 4/6: sparse
        timed("demo-apr-106", 2026, 4, 7, 18, 0, 19, 30, title: "サッカー振替練習", tint: coral, location: "駒沢グラウンド")
        timed("demo-apr-106b", 2026, 4, 7, 8, 0, 8, 45, title: "メール整理 — 集中タイム", tint: sea)
        timed("demo-apr-107", 2026, 4, 8, 12, 0, 12, 45, title: "ランチ散歩", tint: sky)
        timed("demo-apr-108", 2026, 4, 9, 14, 0, 15, 30, title: "UXリサーチセッション", tint: lilac, location: "ラボ2")
        timed("demo-apr-108b", 2026, 4, 9, 18, 0, 19, 0, title: "プロトタイプ修正 — ハンドオフ", tint: peach, location: "ラボ2")
        for day in 10 ... 11 {
            add(2026, 4, day, CalendarEvent(id: "demo-apr-tech-\(day)", eventIdentifier: nil, day: day, title: "テックカンファレンス", tint: sky, allDay: true))
        }
        timed("demo-apr-tech11b", 2026, 4, 11, 17, 0, 18, 30, title: "カンファレンス — ブース撤収", tint: coral, location: "幕張メッセ")
        // 4/12: sparse
        timed("demo-apr-109", 2026, 4, 13, 10, 0, 11, 0, title: "人事評価 — 開始", tint: butter, location: "HRカレンダー")
        timed("demo-apr-109b", 2026, 4, 13, 14, 30, 15, 45, title: "1on1 — デザインリード", tint: lilac, location: "静かな部屋")
        timed("demo-apr-110", 2026, 4, 14, 19, 0, 20, 30, title: "落語鑑賞", tint: peach, location: "寄席 — 新宿末広亭")
        timed("demo-apr-111", 2026, 4, 15, 9, 30, 10, 45, title: "アーキテクチャレビュー", tint: sea, location: "ウォールーム")
        timed("demo-apr-111b", 2026, 4, 15, 12, 0, 13, 0, title: "ランチ — プラットフォームチーム", tint: peach, location: "丸の内カフェ")
        timed("demo-apr-112", 2026, 4, 16, 16, 0, 17, 0, title: "レンタカー返却", tint: coral, location: "空港")
        timed("demo-apr-112b", 2026, 4, 16, 10, 30, 11, 30, title: "フライト遅延バッファ", tint: butter, location: "ラウンジ")
        timed("demo-apr-113", 2026, 4, 17, 11, 30, 12, 30, title: "皮膚科", tint: mint, location: "スキンクリニック")

        // 2026-04-18 (SampleData "今日")
        add(2026, 4, 18, CalendarEvent(
            id: "demo-apr-today-001", eventIdentifier: nil, day: 18,
            startDate: date(2026, 4, 18, h: 8, min: 0),
            endDate: date(2026, 4, 18, h: 9, min: 30),
            title: "朝食 — 美咲と", tint: peach, location: "パン屋 小麦の丘", allDay: false
        ))
        timed("demo-apr-today-progress", 2026, 4, 18, 10, 0, 20, 0, title: "App Store仕上げ — 集中ブロック", tint: sea, location: "ホームオフィス")
        add(2026, 4, 18, CalendarEvent(
            id: "demo-apr-today-002", eventIdentifier: nil, day: 18,
            startDate: date(2026, 4, 18, h: 12, min: 30),
            endDate: date(2026, 4, 18, h: 13, min: 45),
            title: "チームランチ", tint: mint, location: "トラットリア", allDay: false
        ))
        add(2026, 4, 18, CalendarEvent(id: "demo-apr-today-003", eventIdentifier: nil, day: 18, title: "家族の集まり（終日）", tint: rose, location: "祖父母の家", allDay: true))
        add(2026, 4, 18, CalendarEvent(
            id: "demo-apr-today-004", eventIdentifier: nil, day: 18,
            startDate: date(2026, 4, 18, h: 20, min: 15),
            endDate: date(2026, 4, 18, h: 23, min: 15),
            title: "映画: デューン パート2", tint: coral, location: "TOHOシネマズ 日比谷", allDay: false
        ))

        timed("demo-apr-114", 2026, 4, 19, 10, 0, 11, 30, title: "日曜ジョギング", tint: mint, location: "駒沢公園")
        timed("demo-apr-114b", 2026, 4, 19, 15, 0, 17, 0, title: "作り置き + ポッドキャスト", tint: sky)
        timed("demo-apr-115", 2026, 4, 20, 13, 0, 14, 0, title: "給与承認", tint: butter, location: "経理ポータル")
        timed("demo-apr-116", 2026, 4, 21, 17, 30, 18, 45, title: "テニスダブルス", tint: sky, location: "コート")
        timed("demo-apr-117", 2026, 4, 22, 8, 0, 8, 45, title: "フライトチェックイン", tint: lilac)
        timed("demo-apr-118", 2026, 4, 23, 15, 0, 16, 30, title: "ポッドキャスト収録", tint: peach, location: "自宅スタジオ")
        timed("demo-apr-118b", 2026, 4, 23, 19, 0, 20, 0, title: "ポッドキャスト仮編集", tint: lilac, location: "自宅スタジオ")
        // 4/24: sparse
        add(2026, 4, 25, CalendarEvent(id: "demo-apr-004", eventIdentifier: nil, day: 25, title: "日帰り旅行 — 鎌倉", tint: sea, allDay: true))
        timed("demo-apr-004b", 2026, 4, 25, 8, 30, 9, 15, title: "お弁当 + 準備", tint: butter)
        timed("demo-apr-120", 2026, 4, 26, 14, 0, 15, 0, title: "植え替えパーティー", tint: rose, location: "ベランダ")
        timed("demo-apr-121", 2026, 4, 27, 9, 0, 10, 0, title: "セキュリティ研修（年次）", tint: coral, location: "LMS")
        timed("demo-apr-122", 2026, 4, 28, 18, 0, 19, 15, title: "パン教室: カンパーニュ", tint: lilac, location: "料理スタジオ")
        add(2026, 4, 29, CalendarEvent(id: "demo-apr-showa", eventIdentifier: nil, day: 29, title: "昭和の日", tint: butter, allDay: true))
        timed("demo-apr-123", 2026, 4, 29, 11, 0, 12, 0, title: "ベンダーデモ — 分析ツール", tint: sea, location: "Zoom")
        // 4/30: sparse

        // MARK: 5月
        add(2026, 5, 1, CalendarEvent(id: "demo-may-001", eventIdentifier: nil, day: 1, title: "メーデー", tint: rose, allDay: true))
        timed("demo-may-001b", 2026, 5, 1, 8, 30, 9, 30, title: "地域ボランティア準備", tint: sea, location: "町内会館")
        timed("demo-may-101", 2026, 5, 2, 10, 0, 12, 0, title: "フリマ準備", tint: peach, location: "駐車場")
        timed("demo-may-101b", 2026, 5, 2, 14, 0, 16, 0, title: "フリマ片付け", tint: butter, location: "駐車場")
        add(2026, 5, 3, CalendarEvent(id: "demo-may-kenpo", eventIdentifier: nil, day: 3, title: "憲法記念日", tint: lilac, allDay: true))
        timed("demo-may-102", 2026, 5, 3, 15, 30, 17, 0, title: "ピアノ発表会", tint: sky, location: "音楽アカデミー")
        add(2026, 5, 4, CalendarEvent(id: "demo-may-midori", eventIdentifier: nil, day: 4, title: "みどりの日", tint: mint, allDay: true))
        timed("demo-may-103", 2026, 5, 4, 9, 0, 10, 30, title: "取締役会準備", tint: sea, location: "会議室B")
        add(2026, 5, 5, CalendarEvent(id: "demo-may-kodomo", eventIdentifier: nil, day: 5, title: "こどもの日", tint: coral, allDay: true))
        timed("demo-may-104", 2026, 5, 5, 12, 15, 13, 0, title: "柏餅づくり", tint: peach, location: "自宅")
        timed("demo-may-104b", 2026, 5, 5, 16, 0, 17, 0, title: "鯉のぼり見物", tint: sky, location: "多摩川河川敷")
        // 5/6: sparse (振替休日)
        timed("demo-may-106", 2026, 5, 7, 18, 30, 20, 0, title: "合唱団の練習", tint: sky, location: "教会ホール")
        timed("demo-may-106b", 2026, 5, 7, 12, 30, 13, 15, title: "合唱楽譜受け取り", tint: lilac, location: "教会ホール")
        timed("demo-may-107", 2026, 5, 8, 14, 0, 15, 30, title: "1on1 — キャリア相談", tint: butter, location: "コーヒーラボ")
        add(2026, 5, 9, CalendarEvent(
            id: "demo-may-002", eventIdentifier: nil, day: 9,
            startDate: date(2026, 5, 9, h: 10, min: 0),
            endDate: date(2026, 5, 9, h: 14, min: 0),
            title: "母の日ブランチ", tint: peach, location: "ホテルニューオータニ", allDay: false
        ))
        timed("demo-may-002b", 2026, 5, 9, 8, 0, 9, 0, title: "花 + カード買い出し", tint: rose, location: "青山フラワーマーケット")
        add(2026, 5, 10, CalendarEvent(id: "demo-may-108", eventIdentifier: nil, day: 10, title: "庭の植え替え日", tint: mint, allDay: true))
        timed("demo-may-108b", 2026, 5, 10, 16, 0, 17, 30, title: "新しい花壇の水やり", tint: sea, location: "庭")
        timed("demo-may-109", 2026, 5, 11, 16, 0, 17, 30, title: "歯医者 — フォローアップ", tint: sea, location: "田中歯科")
        // 5/12: sparse
        timed("demo-may-111", 2026, 5, 13, 19, 0, 21, 30, title: "野球観戦", tint: sky, location: "神宮球場")
        timed("demo-may-112", 2026, 5, 14, 8, 30, 9, 30, title: "読み聞かせボランティア", tint: rose, location: "教室204")
        timed("demo-may-113", 2026, 5, 15, 13, 30, 14, 45, title: "デザインシステムワークショップ", tint: coral, location: "デザインラボ")
        timed("demo-may-114", 2026, 5, 16, 10, 30, 11, 45, title: "朝市 + 花", tint: peach, location: "築地場外")
        timed("demo-may-115", 2026, 5, 17, 17, 0, 18, 30, title: "キックボクシング", tint: butter, location: "ジム")
        timed("demo-may-115b", 2026, 5, 17, 8, 30, 9, 15, title: "ストレッチ", tint: mint, location: "自宅")
        // 5/18: sparse
        timed("demo-may-117", 2026, 5, 19, 9, 15, 10, 0, title: "夏の航空券予約", tint: lilac)
        add(2026, 5, 20, CalendarEvent(id: "demo-may-003", eventIdentifier: nil, day: 20, title: "リリース期限 — カレンダーアプリ", tint: lilac, allDay: true))
        timed("demo-may-003b", 2026, 5, 20, 10, 0, 10, 45, title: "リリースチェックリスト — 最終確認", tint: coral, location: "Zoom")
        timed("demo-may-118", 2026, 5, 21, 15, 0, 16, 0, title: "チーム振り返り", tint: sea, location: "Miro")
        timed("demo-may-118b", 2026, 5, 21, 9, 30, 10, 15, title: "振り返り準備 — メモ", tint: butter)
        timed("demo-may-119", 2026, 5, 22, 20, 0, 22, 0, title: "お笑いライブ", tint: peach, location: "ルミネtheよしもと")
        add(2026, 5, 23, CalendarEvent(id: "demo-may-120", eventIdentifier: nil, day: 23, title: "週末キャンプ", tint: sky, location: "奥多摩", allDay: true))
        timed("demo-may-120b", 2026, 5, 23, 17, 0, 18, 30, title: "焚き火 + BBQ", tint: peach, location: "奥多摩")
        // 5/24: sparse
        timed("demo-may-122", 2026, 5, 25, 10, 0, 11, 30, title: "レンタル用品返却", tint: rose, location: "アウトドアショップ")
        timed("demo-may-123", 2026, 5, 26, 14, 30, 15, 45, title: "カウンセリング", tint: mint)
        timed("demo-may-124", 2026, 5, 27, 8, 0, 9, 0, title: "全社ミーティング（APAC）", tint: butter, location: "Zoom")
        timed("demo-may-125", 2026, 5, 28, 18, 0, 19, 30, title: "デートナイト", tint: lilac, location: "鮨おまかせ")
        timed("demo-may-126", 2026, 5, 29, 12, 0, 13, 0, title: "ランチ — 投資家アップデート", tint: sea, location: "丸の内レストラン")
        timed("demo-may-126b", 2026, 5, 29, 15, 30, 16, 30, title: "投資家フォローアップメール", tint: lilac)
        // 5/30: sparse
        add(2026, 5, 31, CalendarEvent(id: "demo-may-127", eventIdentifier: nil, day: 31, title: "月次写真バックアップ", tint: sky, allDay: true))
        timed("demo-may-127b", 2026, 5, 31, 18, 0, 18, 45, title: "iCloudバックアップ確認", tint: mint)

        // MARK: 6月
        timed("demo-jun-101", 2026, 6, 1, 9, 30, 10, 30, title: "OKR評価", tint: butter, location: "Notion")
        timed("demo-jun-101b", 2026, 6, 1, 14, 0, 15, 0, title: "OKR — 上司承認", tint: sea, location: "Zoom")
        timed("demo-jun-102", 2026, 6, 2, 17, 0, 18, 30, title: "子どもの水泳教室", tint: sea, location: "スイミングスクール")
        timed("demo-jun-103", 2026, 6, 3, 12, 30, 13, 30, title: "ランチ勉強会 — プライバシー", tint: lilac, location: "Zoom")
        timed("demo-jun-103b", 2026, 6, 3, 16, 0, 16, 45, title: "個人情報チェックリスト", tint: coral, location: "Drive")
        timed("demo-jun-104", 2026, 6, 4, 19, 30, 21, 0, title: "野外映画上映会", tint: peach, location: "公園の野外ステージ")
        timed("demo-jun-104b", 2026, 6, 4, 17, 0, 18, 30, title: "レジャーシート + おやつ準備", tint: mint, location: "公園")
        add(2026, 6, 5, CalendarEvent(id: "demo-jun-105", eventIdentifier: nil, day: 5, title: "物置整理", tint: coral, allDay: true))
        timed("demo-jun-105b", 2026, 6, 5, 10, 0, 12, 0, title: "粗大ごみ搬出", tint: butter, location: "クリーンセンター")
        // 6/6: sparse
        timed("demo-jun-107", 2026, 6, 7, 15, 0, 16, 30, title: "父の日 — 焼肉", tint: rose, location: "叙々苑")
        timed("demo-jun-108", 2026, 6, 8, 10, 0, 11, 0, title: "オンコール引き継ぎ", tint: sky, location: "PagerDuty")
        timed("demo-jun-109", 2026, 6, 9, 13, 0, 14, 30, title: "ポートフォリオ確認", tint: butter, location: "証券会社")
        timed("demo-jun-110", 2026, 6, 10, 18, 0, 19, 15, title: "ボルダリング", tint: coral, location: "B-PUMP 秋葉原")
        timed("demo-jun-111", 2026, 6, 11, 11, 30, 12, 45, title: "ランチ — 新PMご挨拶", tint: peach, location: "屋上カフェ")
        timed("demo-jun-111b", 2026, 6, 11, 9, 0, 9, 45, title: "事前資料 — PRD v3", tint: lilac, location: "Notion")
        // 6/12: sparse
        add(2026, 6, 13, CalendarEvent(id: "demo-jun-113", eventIdentifier: nil, day: 13, title: "週末旅行 — 熱海", tint: sky, location: "海の見える宿", allDay: true))
        timed("demo-jun-113b", 2026, 6, 13, 17, 0, 19, 0, title: "夕日散歩 — 海岸", tint: coral, location: "熱海サンビーチ")
        timed("demo-jun-114", 2026, 6, 14, 10, 0, 11, 30, title: "チェックアウト前のブランチ", tint: mint, location: "海の見える宿")
        timed("demo-jun-115", 2026, 6, 15, 16, 0, 17, 0, title: "洗車", tint: sea, location: "カーウォッシュ")
        timed("demo-jun-116", 2026, 6, 16, 9, 0, 10, 30, title: "アクセシビリティ監査", tint: rose, location: "テストラボ")
        timed("demo-jun-117", 2026, 6, 17, 14, 0, 15, 30, title: "寄付品お届け", tint: butter, location: "セカンドストリート")
        timed("demo-jun-117b", 2026, 6, 17, 10, 0, 11, 0, title: "寄付品の仕分け", tint: mint, location: "ガレージ")
        // 6/18: sparse
        timed("demo-jun-119", 2026, 6, 19, 12, 0, 13, 0, title: "インターン発表会", tint: coral, location: "タウンホール配信")
        timed("demo-jun-119b", 2026, 6, 19, 15, 30, 16, 30, title: "インターンQ&A", tint: sea, location: "Slack ハドル")
        timed("demo-jun-120", 2026, 6, 20, 8, 45, 10, 15, title: "庭仕事パーティー", tint: peach, location: "庭")
        add(2026, 6, 21, CalendarEvent(
            id: "demo-jun-001", eventIdentifier: nil, day: 21,
            startDate: date(2026, 6, 21, h: 18, min: 0),
            endDate: date(2026, 6, 21, h: 22, min: 30),
            title: "夏至 — BBQパーティー", tint: coral, location: "テラス", allDay: false
        ))
        timed("demo-jun-121", 2026, 6, 22, 9, 30, 10, 45, title: "ベンダーセキュリティレビュー", tint: sea, location: "Zoom")
        timed("demo-jun-122", 2026, 6, 23, 17, 30, 18, 45, title: "健康診断 — 年次", tint: mint, location: "人間ドック")
        // 6/24: sparse
        timed("demo-jun-124", 2026, 6, 25, 19, 0, 20, 30, title: "町内会の集会", tint: butter, location: "公民館")
        timed("demo-jun-124b", 2026, 6, 25, 12, 0, 13, 0, title: "集会 — 発言メモ準備", tint: lilac)
        timed("demo-jun-125", 2026, 6, 26, 11, 0, 12, 30, title: "四半期計画ドラフト", tint: lilac, location: "Notion / FigJam")
        timed("demo-jun-126", 2026, 6, 27, 15, 0, 16, 30, title: "蚤の市散策", tint: peach, location: "大江戸骨董市")
        add(2026, 6, 28, CalendarEvent(id: "demo-jun-002", eventIdentifier: nil, day: 28, title: "結婚式 — 陽子 & 健太", tint: rose, location: "鎌倉 鶴岡八幡宮", allDay: true))
        timed("demo-jun-002b", 2026, 6, 28, 8, 0, 9, 30, title: "結婚式 — ヘアメイク", tint: peach, location: "ホテル")
        timed("demo-jun-127", 2026, 6, 29, 10, 0, 11, 0, title: "結婚式翌日ブランチ", tint: mint, location: "ホテルテラス")
        timed("demo-jun-127b", 2026, 6, 29, 14, 0, 15, 30, title: "お礼状書き", tint: butter, location: "ホテルロビー")
        // 6/30: sparse

        sortedMap(&out)
        return out
    }
    // swiftlint:enable function_body_length
}
