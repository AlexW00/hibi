import Foundation

/// Single home for every localized demo string (event titles, venue names,
/// reminder titles). Keeping all six languages in one file — rather than a
/// file per locale — is what keeps demo mode from sprawling: the schedule
/// *shape* lives in `DemoFixtures`, the *words* live here.
///
/// Venue names are intentionally shared across locales (proper-noun cafés /
/// studios read naturally untranslated); only titles and reminders are
/// localized. Translations follow the "natural, not literal" rule in AGENTS.md.
enum DemoStrings {
    typealias Language = DemoFixtures.Language

    // MARK: - Event titles

    static func eventTitle(_ key: String, _ language: Language) -> String {
        (eventTitles(language)[key] ?? key)
    }

    private static func eventTitles(_ language: Language) -> [String: String] {
        switch language {
        case .english:
            return [
                "run": "Morning run",
                "standup": "Team stand-up",
                "lunch": "Lunch with Mara",
                "review": "Design review",
                "dinner": "Dinner with friends",
                "coffee": "Coffee with Sam",
                "yoga": "Yoga class",
                "haircut": "Haircut",
                "grocery": "Groceries",
                "bookclub": "Book club",
                "birthday": "Birthday party",
                "deadline": "Project deadline",
            ]
        case .german:
            return [
                "run": "Morgenlauf",
                "standup": "Team-Stand-up",
                "lunch": "Mittagessen mit Mara",
                "review": "Design-Review",
                "dinner": "Abendessen mit Freunden",
                "coffee": "Kaffee mit Sam",
                "yoga": "Yoga-Kurs",
                "haircut": "Friseurtermin",
                "grocery": "Einkaufen",
                "bookclub": "Lesekreis",
                "birthday": "Geburtstagsfeier",
                "deadline": "Projekt-Deadline",
            ]
        case .japanese:
            return [
                "run": "朝のランニング",
                "standup": "チームの朝会",
                "lunch": "マラとランチ",
                "review": "デザインレビュー",
                "dinner": "友達と夕食",
                "coffee": "サムとコーヒー",
                "yoga": "ヨガ教室",
                "haircut": "美容院",
                "grocery": "買い出し",
                "bookclub": "読書会",
                "birthday": "誕生日パーティー",
                "deadline": "プロジェクトの締め切り",
            ]
        case .korean:
            return [
                "run": "아침 러닝",
                "standup": "팀 스탠드업",
                "lunch": "마라랑 점심",
                "review": "디자인 리뷰",
                "dinner": "친구들과 저녁",
                "coffee": "샘이랑 커피",
                "yoga": "요가 수업",
                "haircut": "미용실",
                "grocery": "장보기",
                "bookclub": "독서 모임",
                "birthday": "생일 파티",
                "deadline": "프로젝트 마감",
            ]
        case .chineseSimplified:
            return [
                "run": "晨跑",
                "standup": "团队站会",
                "lunch": "和玛拉吃午饭",
                "review": "设计评审",
                "dinner": "和朋友吃晚饭",
                "coffee": "和山姆喝咖啡",
                "yoga": "瑜伽课",
                "haircut": "理发",
                "grocery": "买菜",
                "bookclub": "读书会",
                "birthday": "生日派对",
                "deadline": "项目截止",
            ]
        case .chineseTraditional:
            return [
                "run": "晨跑",
                "standup": "團隊站立會議",
                "lunch": "和瑪拉吃午餐",
                "review": "設計審查",
                "dinner": "和朋友吃晚餐",
                "coffee": "和山姆喝咖啡",
                "yoga": "瑜珈課",
                "haircut": "剪髮",
                "grocery": "買菜",
                "bookclub": "讀書會",
                "birthday": "生日派對",
                "deadline": "專案截止",
            ]
        }
    }

    // MARK: - Venue names (shared across locales)

    static func location(_ key: String) -> String {
        sharedLocations[key] ?? key
    }

    private static let sharedLocations: [String: String] = [
        "zoom": "Zoom",
        "studio": "Studio B",
        "saffron": "Saffron Table",
        "lumi": "Café Lumi",
        "bluebottle": "Blue Bottle",
        "studionorth": "Studio North",
        "salon": "Salon Lina",
        "market": "Market Hall",
    ]

    // MARK: - Reminder titles

    static func reminderTitle(_ key: String, _ language: Language) -> String {
        (reminderTitles(language)[key] ?? key)
    }

    private static func reminderTitles(_ language: Language) -> [String: String] {
        switch language {
        case .english:
            return [
                "water_plants": "Water the plants",
                "call_dentist": "Call the dentist",
                "tax_documents": "Send tax documents",
                "pick_up_parcel": "Pick up parcel",
                "dry_cleaning": "Collect dry cleaning",
                "birthday_gift": "Buy birthday gift",
                "library_books": "Renew library books",
            ]
        case .german:
            return [
                "water_plants": "Pflanzen gießen",
                "call_dentist": "Beim Zahnarzt anrufen",
                "tax_documents": "Steuerunterlagen abschicken",
                "pick_up_parcel": "Paket abholen",
                "dry_cleaning": "Wäsche aus der Reinigung holen",
                "birthday_gift": "Geburtstagsgeschenk kaufen",
                "library_books": "Bücher verlängern",
            ]
        case .japanese:
            return [
                "water_plants": "植物に水やり",
                "call_dentist": "歯医者に電話",
                "tax_documents": "確定申告の書類を送る",
                "pick_up_parcel": "荷物を受け取る",
                "dry_cleaning": "クリーニングを取りに行く",
                "birthday_gift": "誕生日プレゼントを買う",
                "library_books": "図書館の本を延長",
            ]
        case .korean:
            return [
                "water_plants": "화분에 물 주기",
                "call_dentist": "치과 예약 전화하기",
                "tax_documents": "세금 서류 보내기",
                "pick_up_parcel": "택배 찾기",
                "dry_cleaning": "세탁물 찾아오기",
                "birthday_gift": "생일 선물 사기",
                "library_books": "도서관 책 연장하기",
            ]
        case .chineseSimplified:
            return [
                "water_plants": "给植物浇水",
                "call_dentist": "打电话给牙医",
                "tax_documents": "寄送报税材料",
                "pick_up_parcel": "取快递",
                "dry_cleaning": "取干洗的衣服",
                "birthday_gift": "买生日礼物",
                "library_books": "续借图书馆的书",
            ]
        case .chineseTraditional:
            return [
                "water_plants": "幫植物澆水",
                "call_dentist": "打電話給牙醫",
                "tax_documents": "寄送報稅文件",
                "pick_up_parcel": "領取包裹",
                "dry_cleaning": "拿乾洗的衣服",
                "birthday_gift": "買生日禮物",
                "library_books": "續借圖書館的書",
            ]
        }
    }
}
