import Foundation
import SwiftUI

extension DemoFixtures {
    // swiftlint:disable function_body_length
    static func makeEnglishEvents() -> EventMap {
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

        // MARK: February
        add(2026, 2, 1, CalendarEvent(id: "demo-feb-101", eventIdentifier: nil, day: 1, title: "Monthly budget review", tint: butter, allDay: true))
        timed("demo-feb-101b", 2026, 2, 1, 15, 0, 15, 45, title: "Quarterly planning — finance", tint: sea, location: "Zoom")
        timed("demo-feb-102", 2026, 2, 2, 9, 0, 9, 45, title: "Yoga — early bird", tint: mint, location: "Studio North", recurring: true)
        add(2026, 2, 3, CalendarEvent(id: "demo-feb-001", eventIdentifier: nil, day: 3, title: "Anna's birthday", tint: rose, allDay: true))
        timed("demo-feb-001b", 2026, 2, 3, 19, 0, 22, 0, title: "Birthday dinner — close friends", tint: lilac, location: "Saffron Table")
        timed("demo-feb-103", 2026, 2, 4, 12, 0, 12, 30, title: "Dentist — quick polish", tint: sea, location: "Bright Smile Clinic")
        timed("demo-feb-104", 2026, 2, 5, 18, 0, 19, 30, title: "Cooking class: pasta", tint: peach, location: "Kitchen Collective")
        timed("demo-feb-106", 2026, 2, 7, 10, 30, 11, 30, title: "Book club", tint: sky, location: "River Café")
        timed("demo-feb-106b", 2026, 2, 7, 16, 0, 17, 0, title: "Groceries + meal prep", tint: butter, location: "Whole Foods")
        timed("demo-feb-107", 2026, 2, 8, 15, 0, 16, 0, title: "Kids' soccer practice", tint: coral, location: "East Fields")
        timed("demo-feb-108", 2026, 2, 9, 8, 30, 9, 15, title: "1:1 with Alex", tint: sea, location: "Meet — Boreal room", recurring: true)
        timed("demo-feb-109", 2026, 2, 10, 19, 0, 20, 30, title: "Jazz night", tint: lilac, location: "Blue Note Loft")
        add(2026, 2, 11, CalendarEvent(id: "demo-feb-110", eventIdentifier: nil, day: 11, title: "Car service & inspection", tint: butter, location: "AutoCare Plus", allDay: true))
        timed("demo-feb-110b", 2026, 2, 11, 14, 0, 15, 30, title: "Pick up rental car", tint: coral, location: "AutoCare Plus")
        timed("demo-feb-112", 2026, 2, 13, 17, 30, 18, 30, title: "Therapy session", tint: sky, recurring: true)
        add(2026, 2, 14, CalendarEvent(
            id: "demo-feb-002", eventIdentifier: nil, day: 14,
            startDate: date(2026, 2, 14, h: 10, min: 0),
            endDate: date(2026, 2, 14, h: 12, min: 30),
            title: "Valentine's brunch", tint: peach, location: "Crown Café", allDay: false
        ))
        timed("demo-feb-002b", 2026, 2, 14, 18, 30, 20, 0, title: "Sunset walk — river path", tint: rose, location: "Waterfront")
        timed("demo-feb-113", 2026, 2, 15, 14, 0, 15, 30, title: "Museum — impressionists", tint: lilac, location: "City Art Museum")
        timed("demo-feb-114", 2026, 2, 16, 11, 0, 12, 0, title: "Parent-teacher conference", tint: coral, location: "Lincoln Elementary")
        timed("demo-feb-115", 2026, 2, 17, 16, 0, 17, 0, title: "Guitar lesson", tint: sea)
        timed("demo-feb-117", 2026, 2, 19, 20, 0, 22, 30, title: "Hockey — home game", tint: sky, location: "Arena District")
        for day in 20 ... 22 {
            add(2026, 2, day, CalendarEvent(id: "demo-feb-ski-\(day)", eventIdentifier: nil, day: day, title: "Ski trip — Zillertal", tint: sky, allDay: true))
        }
        timed("demo-feb-ski21b", 2026, 2, 21, 17, 0, 18, 30, title: "Après-ski — fondue", tint: peach, location: "Alpine Lodge")
        timed("demo-feb-118", 2026, 2, 23, 13, 0, 14, 0, title: "Lunch — investors", tint: peach, location: "Harbor House")
        timed("demo-feb-118b", 2026, 2, 23, 16, 30, 17, 30, title: "Walk-through — new space", tint: mint, location: "WeWork")
        add(2026, 2, 25, CalendarEvent(id: "demo-feb-120", eventIdentifier: nil, day: 25, title: "Quarterly tax prep", tint: rose, allDay: true))
        timed("demo-feb-121", 2026, 2, 26, 8, 0, 8, 30, title: "Flight to Berlin", tint: lilac, location: "Gate B12")
        timed("demo-feb-122", 2026, 2, 27, 12, 30, 13, 30, title: "Design critique", tint: coral, location: "Figma / HQ-4")
        add(2026, 2, 28, CalendarEvent(id: "demo-feb-123", eventIdentifier: nil, day: 28, title: "Winter sale — last day", tint: butter, allDay: true))

        // MARK: March
        add(2026, 3, 1, CalendarEvent(id: "demo-mar-101", eventIdentifier: nil, day: 1, title: "Spring closet swap", tint: lilac, allDay: true))
        timed("demo-mar-101b", 2026, 3, 1, 14, 0, 15, 0, title: "Donation drop — clothes", tint: coral, location: "Salvation Army")
        timed("demo-mar-102", 2026, 3, 2, 9, 30, 10, 30, title: "All-hands (hybrid)", tint: sea, location: "Town Hall A")
        timed("demo-mar-102b", 2026, 3, 2, 15, 0, 16, 0, title: "Design critique — follow-up", tint: lilac, location: "Figma")
        timed("demo-mar-103", 2026, 3, 3, 17, 0, 18, 15, title: "Physical therapy", tint: mint, location: "MoveWell Center")
        timed("demo-mar-104", 2026, 3, 4, 12, 0, 13, 0, title: "Lunch & learn — SwiftUI", tint: peach, location: "Dev lounge")
        timed("demo-mar-104b", 2026, 3, 4, 18, 0, 19, 0, title: "Run club — easy 5K", tint: sky, location: "Waterfront")
        add(2026, 3, 5, CalendarEvent(id: "demo-mar-105", eventIdentifier: nil, day: 5, title: "Submit expense reports", tint: butter, allDay: true))
        timed("demo-mar-107", 2026, 3, 7, 11, 0, 12, 30, title: "Brunch with parents", tint: rose, location: "The Orchard")
        add(2026, 3, 8, CalendarEvent(
            id: "demo-mar-001", eventIdentifier: nil, day: 8,
            startDate: date(2026, 3, 8, h: 11, min: 0),
            endDate: date(2026, 3, 8, h: 13, min: 0),
            title: "Women's Day — family coffee", tint: lilac, location: "Home", allDay: false
        ))
        timed("demo-mar-108", 2026, 3, 9, 14, 0, 15, 30, title: "Photography walk", tint: coral, location: "Waterfront trail")
        timed("demo-mar-110", 2026, 3, 10, 8, 0, 9, 0, title: "Dentist cleaning", tint: sea, location: "Bright Smile Clinic")
        timed("demo-mar-111", 2026, 3, 11, 19, 30, 21, 0, title: "Indie film screening", tint: lilac, location: "Little Theater")
        timed("demo-mar-113", 2026, 3, 13, 16, 0, 17, 30, title: "Haircut", tint: peach, location: "Studio M")
        timed("demo-mar-114", 2026, 3, 14, 9, 0, 11, 0, title: "Farmers market + coffee", tint: mint, location: "Riverside")
        timed("demo-mar-114b", 2026, 3, 14, 15, 0, 16, 30, title: "Nap + laundry", tint: butter)
        add(2026, 3, 15, CalendarEvent(
            id: "demo-mar-002", eventIdentifier: nil, day: 15,
            startDate: date(2026, 3, 15, h: 15, min: 30),
            endDate: date(2026, 3, 15, h: 16, min: 30),
            title: "Dentist checkup", tint: mint, location: "Dr. Weber Family Dental", allDay: false
        ))
        add(2026, 3, 16, CalendarEvent(id: "demo-mar-115", eventIdentifier: nil, day: 16, title: "HOA meeting", tint: sky, location: "Community center", allDay: true))
        timed("demo-mar-116", 2026, 3, 17, 18, 0, 19, 30, title: "Pickleball league", tint: coral, location: "Courts 3–4")
        timed("demo-mar-119", 2026, 3, 19, 7, 30, 8, 15, title: "Spin class", tint: rose, location: "Pulse Gym")
        timed("demo-mar-120", 2026, 3, 20, 13, 0, 14, 30, title: "Lunch — mentor coffee", tint: peach, location: "Daily Grind")
        timed("demo-mar-120b", 2026, 3, 20, 17, 0, 18, 0, title: "Code review — calendar widgets", tint: sea, location: "Zoom")
        add(2026, 3, 21, CalendarEvent(id: "demo-mar-121", eventIdentifier: nil, day: 21, title: "Spring equinox hike", tint: mint, location: "Pine Ridge Trail", allDay: true))
        timed("demo-mar-122", 2026, 3, 22, 15, 0, 16, 30, title: "Kids' birthday party", tint: lilac, location: "Bounce House")
        timed("demo-mar-122b", 2026, 3, 22, 10, 0, 11, 30, title: "Party setup (decorations)", tint: sky, location: "Bounce House")
        timed("demo-mar-123", 2026, 3, 23, 9, 30, 10, 30, title: "Legal review — contracts", tint: butter, location: "WeWork — 9th floor")
        timed("demo-mar-125", 2026, 3, 25, 11, 30, 12, 30, title: "Office hours (open)", tint: coral, location: "Slack huddle")
        timed("demo-mar-126", 2026, 3, 26, 17, 0, 18, 0, title: "Dog training class", tint: sea, location: "Happy Paws Park")
        timed("demo-mar-127", 2026, 3, 27, 8, 45, 9, 30, title: "School drop-off duty", tint: peach)
        add(2026, 3, 28, CalendarEvent(id: "demo-mar-003", eventIdentifier: nil, day: 28, title: "Spring deep clean", tint: butter, allDay: true))
        timed("demo-mar-128", 2026, 3, 29, 14, 0, 15, 0, title: "Charity 5K packet pickup", tint: rose, location: "Convention Hall")
        add(2026, 3, 31, CalendarEvent(id: "demo-mar-130", eventIdentifier: nil, day: 31, title: "Q1 wrap-up notes due", tint: sky, allDay: true))

        // MARK: April (dense — primary demo month)
        add(2026, 4, 1, CalendarEvent(id: "demo-apr-101", eventIdentifier: nil, day: 1, title: "April Fool's — no pranks please", tint: butter, allDay: true))
        timed("demo-apr-101b", 2026, 4, 1, 11, 0, 11, 45, title: "Team prank debrief (real)", tint: lilac, location: "Slack")
        timed("demo-apr-102", 2026, 4, 2, 9, 0, 10, 0, title: "Stand-up", tint: sea, location: "Zoom")
        timed("demo-apr-103", 2026, 4, 2, 15, 30, 16, 30, title: "Tea with neighbor", tint: peach, location: "Patio")
        add(2026, 4, 3, CalendarEvent(
            id: "demo-apr-001", eventIdentifier: nil, day: 3,
            startDate: date(2026, 4, 3, h: 10, min: 0),
            endDate: date(2026, 4, 3, h: 11, min: 30),
            title: "Team stand-up & roadmap", tint: sea, location: "Zoom", allDay: false
        ))
        timed("demo-apr-001b", 2026, 4, 3, 14, 0, 15, 30, title: "Roadmap — stakeholder Q&A", tint: lilac, location: "Zoom")
        timed("demo-apr-104", 2026, 4, 4, 11, 0, 12, 30, title: "Brunch — Easter weekend", tint: rose, location: "Garden Bistro")
        timed("demo-apr-104b", 2026, 4, 4, 16, 0, 17, 30, title: "Egg hunt — neighborhood", tint: mint, location: "Park")
        add(2026, 4, 5, CalendarEvent(
            id: "demo-apr-002", eventIdentifier: nil, day: 5,
            startDate: date(2026, 4, 5, h: 19, min: 30),
            endDate: date(2026, 4, 5, h: 22, min: 0),
            title: "Chamber orchestra concert", tint: lilac, location: "Symphony Hall", allDay: false
        ))
        timed("demo-apr-005b", 2026, 4, 5, 10, 0, 11, 30, title: "Matinee — family film", tint: butter, location: "Multiplex")
        timed("demo-apr-106", 2026, 4, 7, 18, 0, 19, 30, title: "Soccer practice (make-up)", tint: coral, location: "East Fields")
        timed("demo-apr-106b", 2026, 4, 7, 8, 0, 8, 45, title: "Email triage — deep work", tint: sea)
        timed("demo-apr-107", 2026, 4, 8, 12, 0, 12, 45, title: "Lunch walk", tint: sky)
        timed("demo-apr-108", 2026, 4, 9, 14, 0, 15, 30, title: "UX research sessions", tint: lilac, location: "Lab 2")
        timed("demo-apr-108b", 2026, 4, 9, 18, 0, 19, 0, title: "Prototype tweaks — handoff", tint: peach, location: "Lab 2")
        for day in 10 ... 11 {
            add(2026, 4, day, CalendarEvent(id: "demo-apr-messe-\(day)", eventIdentifier: nil, day: day, title: "Smart Cities Expo", tint: sky, allDay: true))
        }
        timed("demo-apr-messe11b", 2026, 4, 11, 17, 0, 18, 30, title: "Expo — booth teardown", tint: coral, location: "Hall C")
        timed("demo-apr-109", 2026, 4, 13, 10, 0, 11, 0, title: "Performance reviews — open", tint: butter, location: "HR calendar")
        timed("demo-apr-109b", 2026, 4, 13, 14, 30, 15, 45, title: "1:1 — design lead", tint: lilac, location: "Quiet room")
        timed("demo-apr-110", 2026, 4, 14, 19, 0, 20, 30, title: "Poetry open mic", tint: peach, location: "Word & Quill")
        timed("demo-apr-111", 2026, 4, 15, 9, 30, 10, 45, title: "Architecture review", tint: sea, location: "War room")
        timed("demo-apr-111b", 2026, 4, 15, 12, 0, 13, 0, title: "Lunch — platform team", tint: peach, location: "Café Row")
        timed("demo-apr-112", 2026, 4, 16, 16, 0, 17, 0, title: "Car pickup — rental return", tint: coral, location: "Airport lot")
        timed("demo-apr-112b", 2026, 4, 16, 10, 30, 11, 30, title: "Flight delay buffer", tint: butter, location: "Terminal lounge")
        timed("demo-apr-113", 2026, 4, 17, 11, 30, 12, 30, title: "Dermatologist", tint: mint, location: "Skin First")

        // 2026-04-18 (SampleData "today")
        add(2026, 4, 18, CalendarEvent(
            id: "demo-apr-today-001", eventIdentifier: nil, day: 18,
            startDate: date(2026, 4, 18, h: 8, min: 0),
            endDate: date(2026, 4, 18, h: 9, min: 30),
            title: "Breakfast with Maria", tint: peach, location: "Schmitt Bakery", allDay: false
        ))
        timed("demo-apr-today-progress", 2026, 4, 18, 10, 0, 20, 0, title: "App Store polish — focus block", tint: sea, location: "Home office", recurring: true)
        add(2026, 4, 18, CalendarEvent(
            id: "demo-apr-today-002", eventIdentifier: nil, day: 18,
            startDate: date(2026, 4, 18, h: 12, min: 30),
            endDate: date(2026, 4, 18, h: 13, min: 45),
            title: "Team lunch", tint: mint, location: "Osteria Due", allDay: false,
            isRecurring: true
        ))
        add(2026, 4, 18, CalendarEvent(id: "demo-apr-today-003", eventIdentifier: nil, day: 18, title: "Family gathering (all day)", tint: rose, location: "Grandparents' garden", allDay: true))
        add(2026, 4, 18, CalendarEvent(
            id: "demo-apr-today-004", eventIdentifier: nil, day: 18,
            startDate: date(2026, 4, 18, h: 20, min: 15),
            endDate: date(2026, 4, 18, h: 23, min: 15),
            title: "Movie: Dune Part Two", tint: coral, location: "CineStar Downtown", allDay: false
        ))

        timed("demo-apr-114", 2026, 4, 19, 10, 0, 11, 30, title: "Sunday slow run", tint: mint, location: "Lake loop")
        timed("demo-apr-114b", 2026, 4, 19, 15, 0, 17, 0, title: "Meal prep + podcasts", tint: sky)
        timed("demo-apr-115", 2026, 4, 20, 13, 0, 14, 0, title: "Payroll approvals", tint: butter, location: "Finance portal")
        timed("demo-apr-116", 2026, 4, 21, 17, 30, 18, 45, title: "Tennis doubles", tint: sky, location: "Club courts")
        timed("demo-apr-117", 2026, 4, 22, 8, 0, 8, 45, title: "Flight check-in reminder", tint: lilac)
        timed("demo-apr-118", 2026, 4, 23, 15, 0, 16, 30, title: "Podcast recording", tint: peach, location: "Home studio")
        timed("demo-apr-118b", 2026, 4, 23, 19, 0, 20, 0, title: "Edit podcast rough cut", tint: lilac, location: "Home studio")
        add(2026, 4, 25, CalendarEvent(id: "demo-apr-004", eventIdentifier: nil, day: 25, title: "Day trip — lakeside", tint: sea, allDay: true))
        timed("demo-apr-004b", 2026, 4, 25, 8, 30, 9, 15, title: "Pack car + snacks", tint: butter)
        timed("demo-apr-120", 2026, 4, 26, 14, 0, 15, 0, title: "Plant repotting party", tint: rose, location: "Back deck")
        timed("demo-apr-121", 2026, 4, 27, 9, 0, 10, 0, title: "Security training (annual)", tint: coral, location: "LMS link")
        timed("demo-apr-122", 2026, 4, 28, 18, 0, 19, 15, title: "Cooking: sourdough", tint: lilac, location: "Community kitchen")
        timed("demo-apr-123", 2026, 4, 29, 11, 0, 12, 0, title: "Vendor demo — analytics", tint: butter, location: "Zoom")
        timed("demo-apr-123b", 2026, 4, 29, 15, 30, 16, 30, title: "Vendor demo — follow-up", tint: lilac, location: "Zoom")

        // MARK: May
        add(2026, 5, 1, CalendarEvent(id: "demo-may-001", eventIdentifier: nil, day: 1, title: "May Day — neighborhood fair", tint: rose, location: "City Park", allDay: true))
        timed("demo-may-001b", 2026, 5, 1, 8, 30, 9, 30, title: "Fair booth — volunteer setup", tint: sea, location: "City Park")
        timed("demo-may-101", 2026, 5, 2, 10, 0, 12, 0, title: "Yard sale setup", tint: peach, location: "Driveway")
        timed("demo-may-101b", 2026, 5, 2, 14, 0, 16, 0, title: "Yard sale — tear-down", tint: butter, location: "Driveway")
        timed("demo-may-102", 2026, 5, 3, 15, 30, 17, 0, title: "Piano recital", tint: lilac, location: "Arts Academy")
        timed("demo-may-103", 2026, 5, 4, 9, 0, 10, 30, title: "Board prep session", tint: sea, location: "Boardroom B")
        timed("demo-may-104", 2026, 5, 5, 12, 15, 13, 0, title: "Cinco lunch (team)", tint: coral, location: "Taquería Sol")
        timed("demo-may-104b", 2026, 5, 5, 16, 0, 17, 0, title: "Margarita debrief (optional)", tint: peach, location: "Rooftop")
        timed("demo-may-106", 2026, 5, 7, 18, 30, 20, 0, title: "Community choir", tint: sky, location: "Old Church")
        timed("demo-may-106b", 2026, 5, 7, 12, 30, 13, 15, title: "Choir folder — pick up scores", tint: lilac, location: "Old Church")
        timed("demo-may-107", 2026, 5, 8, 14, 0, 15, 30, title: "1:1 — career chat", tint: butter, location: "Coffee Lab")
        add(2026, 5, 9, CalendarEvent(
            id: "demo-may-002", eventIdentifier: nil, day: 9,
            startDate: date(2026, 5, 9, h: 10, min: 0),
            endDate: date(2026, 5, 9, h: 14, min: 0),
            title: "Mother's Day brunch", tint: peach, location: "Hotel Atlantic", allDay: false
        ))
        timed("demo-may-002b", 2026, 5, 9, 8, 0, 9, 0, title: "Flowers + card pickup", tint: rose, location: "Florist Row")
        add(2026, 5, 10, CalendarEvent(id: "demo-may-108", eventIdentifier: nil, day: 10, title: "Garden planting day", tint: mint, allDay: true))
        timed("demo-may-108b", 2026, 5, 10, 16, 0, 17, 30, title: "Water new beds", tint: sea, location: "Backyard")
        timed("demo-may-109", 2026, 5, 11, 16, 0, 17, 30, title: "Dentist — follow-up X-ray", tint: sea, location: "Bright Smile Clinic")
        timed("demo-may-111", 2026, 5, 13, 19, 0, 21, 30, title: "Baseball night", tint: sky, location: "River Stadium")
        timed("demo-may-112", 2026, 5, 14, 8, 30, 9, 30, title: "School volunteer — reading", tint: rose, location: "Room 204")
        timed("demo-may-113", 2026, 5, 15, 13, 30, 14, 45, title: "Design systems workshop", tint: coral, location: "Design lab")
        timed("demo-may-114", 2026, 5, 16, 10, 30, 11, 45, title: "Farmers market + flowers", tint: peach, location: "Old Town")
        timed("demo-may-115", 2026, 5, 17, 17, 0, 18, 30, title: "Kickboxing", tint: butter, location: "Iron Gym")
        timed("demo-may-115b", 2026, 5, 17, 8, 30, 9, 15, title: "Stretch + mobility", tint: mint, location: "Home")
        timed("demo-may-117", 2026, 5, 19, 9, 15, 10, 0, title: "Flights — summer booking", tint: lilac)
        add(2026, 5, 20, CalendarEvent(id: "demo-may-003", eventIdentifier: nil, day: 20, title: "Ship deadline — Calendar app milestone", tint: lilac, allDay: true))
        timed("demo-may-003b", 2026, 5, 20, 10, 0, 10, 45, title: "Release checklist — final pass", tint: coral, location: "Zoom")
        timed("demo-may-118", 2026, 5, 21, 15, 0, 16, 0, title: "Team retro", tint: sea, location: "Miro")
        timed("demo-may-118b", 2026, 5, 21, 9, 30, 10, 15, title: "Retro prep — notes", tint: butter)
        timed("demo-may-119", 2026, 5, 22, 20, 0, 22, 0, title: "Live comedy", tint: peach, location: "Laugh Track")
        add(2026, 5, 23, CalendarEvent(id: "demo-may-120", eventIdentifier: nil, day: 23, title: "Memorial Day weekend — camping", tint: sky, location: "Pine Lake", allDay: true))
        timed("demo-may-120b", 2026, 5, 23, 17, 0, 18, 30, title: "Campfire + s'mores", tint: peach, location: "Pine Lake")
        timed("demo-may-122", 2026, 5, 25, 10, 0, 11, 30, title: "Return rental gear", tint: rose, location: "Outfitters Co.")
        timed("demo-may-123", 2026, 5, 26, 14, 30, 15, 45, title: "Therapy", tint: mint)
        timed("demo-may-124", 2026, 5, 27, 8, 0, 9, 0, title: "All-hands (EMEA)", tint: butter, location: "Zoom")
        timed("demo-may-125", 2026, 5, 28, 18, 0, 19, 30, title: "Date night", tint: lilac, location: "Sushi Omakase")
        timed("demo-may-126", 2026, 5, 29, 12, 0, 13, 0, title: "Lunch — investor update", tint: sea, location: "Harbor House")
        timed("demo-may-126b", 2026, 5, 29, 15, 30, 16, 30, title: "Investor — follow-up email block", tint: lilac)
        add(2026, 5, 31, CalendarEvent(id: "demo-may-127", eventIdentifier: nil, day: 31, title: "Monthly photo backup", tint: sky, allDay: true))
        timed("demo-may-127b", 2026, 5, 31, 18, 0, 18, 45, title: "Verify iCloud backup", tint: mint)

        // MARK: June
        timed("demo-jun-101", 2026, 6, 1, 9, 30, 10, 30, title: "OKR grading", tint: butter, location: "Notion")
        timed("demo-jun-101b", 2026, 6, 1, 14, 0, 15, 0, title: "OKRs — manager sign-off", tint: sea, location: "Zoom")
        timed("demo-jun-102", 2026, 6, 2, 17, 0, 18, 30, title: "Swim lesson — kids", tint: sea, location: "Aquatic Center")
        timed("demo-jun-103", 2026, 6, 3, 12, 30, 13, 30, title: "Lunch & learn — privacy", tint: lilac, location: "Zoom")
        timed("demo-jun-103b", 2026, 6, 3, 16, 0, 16, 45, title: "Privacy checklist — DPA folder", tint: coral, location: "Drive")
        timed("demo-jun-104", 2026, 6, 4, 19, 30, 21, 0, title: "Outdoor movie", tint: peach, location: "Park amphitheater")
        timed("demo-jun-104b", 2026, 6, 4, 17, 0, 18, 30, title: "Picnic blanket + snacks", tint: mint, location: "Park amphitheater")
        add(2026, 6, 5, CalendarEvent(id: "demo-jun-105", eventIdentifier: nil, day: 5, title: "Garage clean-out", tint: coral, allDay: true))
        timed("demo-jun-105b", 2026, 6, 5, 10, 0, 12, 0, title: "Dump run — first load", tint: butter, location: "Transfer station")
        timed("demo-jun-107", 2026, 6, 7, 15, 0, 16, 30, title: "Father's Day — BBQ", tint: rose, location: "Uncle's backyard")
        timed("demo-jun-108", 2026, 6, 8, 10, 0, 11, 0, title: "On-call handoff", tint: sky, location: "PagerDuty")
        timed("demo-jun-109", 2026, 6, 9, 13, 0, 14, 30, title: "Portfolio review", tint: butter, location: "Advisor office")
        timed("demo-jun-110", 2026, 6, 10, 18, 0, 19, 15, title: "Climbing gym", tint: coral, location: "Vertical Edge")
        timed("demo-jun-111", 2026, 6, 11, 11, 30, 12, 45, title: "Lunch — new PM intro", tint: peach, location: "Rooftop café")
        timed("demo-jun-111b", 2026, 6, 11, 9, 0, 9, 45, title: "Pre-read — PRD v3", tint: lilac, location: "Notion")
        add(2026, 6, 13, CalendarEvent(id: "demo-jun-113", eventIdentifier: nil, day: 13, title: "Beach weekend", tint: sky, location: "Coast Inn", allDay: true))
        timed("demo-jun-113b", 2026, 6, 13, 17, 0, 19, 0, title: "Sunset walk — pier", tint: coral, location: "Coast Inn")
        timed("demo-jun-114", 2026, 6, 14, 10, 0, 11, 30, title: "Brunch before checkout", tint: mint, location: "Coast Inn")
        timed("demo-jun-115", 2026, 6, 15, 16, 0, 17, 0, title: "Car wash + detail", tint: sea, location: "Sparkle Auto")
        timed("demo-jun-116", 2026, 6, 16, 9, 0, 10, 30, title: "Accessibility audit", tint: rose, location: "Test lab")
        timed("demo-jun-117", 2026, 6, 17, 14, 0, 15, 30, title: "Donation drop-off", tint: butter, location: "Goodwill dock")
        timed("demo-jun-117b", 2026, 6, 17, 10, 0, 11, 0, title: "Sort donation boxes", tint: mint, location: "Garage")
        timed("demo-jun-119", 2026, 6, 19, 12, 0, 13, 0, title: "Intern presentations", tint: coral, location: "Town hall stream")
        timed("demo-jun-119b", 2026, 6, 19, 15, 30, 16, 30, title: "Intern Q&A — office hours", tint: sea, location: "Slack huddle")
        timed("demo-jun-120", 2026, 6, 20, 8, 45, 10, 15, title: "Yard work party", tint: peach, location: "Front + side yard")
        add(2026, 6, 21, CalendarEvent(
            id: "demo-jun-001", eventIdentifier: nil, day: 21,
            startDate: date(2026, 6, 21, h: 18, min: 0),
            endDate: date(2026, 6, 21, h: 22, min: 30),
            title: "Summer solstice grill-out", tint: coral, location: "Back terrace", allDay: false
        ))
        timed("demo-jun-121", 2026, 6, 22, 9, 30, 10, 45, title: "Vendor security review", tint: sea, location: "Zoom")
        timed("demo-jun-122", 2026, 6, 23, 17, 30, 18, 45, title: "Physical — annual", tint: mint, location: "Family Health")
        timed("demo-jun-124", 2026, 6, 25, 19, 0, 20, 30, title: "Community town hall", tint: butter, location: "High school auditorium")
        timed("demo-jun-124b", 2026, 6, 25, 12, 0, 13, 0, title: "Town hall — talking points prep", tint: lilac)
        timed("demo-jun-125", 2026, 6, 26, 11, 0, 12, 30, title: "Quarterly planning draft", tint: lilac, location: "Notion / FigJam")
        timed("demo-jun-126", 2026, 6, 27, 15, 0, 16, 30, title: "Flea market browse", tint: peach, location: "Fairgrounds")
        add(2026, 6, 28, CalendarEvent(id: "demo-jun-002", eventIdentifier: nil, day: 28, title: "Wedding — Lisa & Tom", tint: rose, location: "Rheingau Vineyard Estate", allDay: true))
        timed("demo-jun-002b", 2026, 6, 28, 8, 0, 9, 30, title: "Wedding — hair & makeup (VIP)", tint: peach, location: "Estate suite")
        timed("demo-jun-127", 2026, 6, 29, 10, 0, 11, 0, title: "Post-wedding brunch (family)", tint: mint, location: "Estate terrace")
        timed("demo-jun-127b", 2026, 6, 29, 14, 0, 15, 30, title: "Gift thank-you notes", tint: butter, location: "Hotel lobby")

        sortedMap(&out)
        return out
    }
    // swiftlint:enable function_body_length
}
