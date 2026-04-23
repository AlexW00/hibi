import Foundation
import SwiftUI

extension DemoFixtures {
    // swiftlint:disable function_body_length
    static func makeGermanEvents() -> EventMap {
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

        // MARK: Februar
        add(2026, 2, 1, CalendarEvent(id: "demo-feb-101", eventIdentifier: nil, day: 1, title: "Monatsbudget prüfen", tint: butter, allDay: true))
        timed("demo-feb-101b", 2026, 2, 1, 15, 0, 15, 45, title: "Quartalsplanung — Finanzen", tint: sea, location: "Zoom")
        timed("demo-feb-102", 2026, 2, 2, 9, 0, 9, 45, title: "Yoga — Frühkurs", tint: mint, location: "Studio Nord")
        add(2026, 2, 3, CalendarEvent(id: "demo-feb-001", eventIdentifier: nil, day: 3, title: "Annas Geburtstag", tint: rose, allDay: true))
        timed("demo-feb-001b", 2026, 2, 3, 19, 0, 22, 0, title: "Geburtstagsessen — enge Freunde", tint: lilac, location: "Gasthof zur Linde")
        timed("demo-feb-103", 2026, 2, 4, 12, 0, 12, 30, title: "Zahnarzt — Politur", tint: sea, location: "Praxis Dr. Meier")
        timed("demo-feb-104", 2026, 2, 5, 18, 0, 19, 30, title: "Kochkurs: Spätzle", tint: peach, location: "VHS Küche")
        // Feb 6: sparse
        timed("demo-feb-106", 2026, 2, 7, 10, 30, 11, 30, title: "Lesekreis", tint: sky, location: "Café am Fluss")
        timed("demo-feb-106b", 2026, 2, 7, 16, 0, 17, 0, title: "Einkaufen + Meal Prep", tint: butter, location: "REWE")
        timed("demo-feb-107", 2026, 2, 8, 15, 0, 16, 0, title: "Fußball-Training der Kinder", tint: coral, location: "Sportplatz Ost")
        timed("demo-feb-108", 2026, 2, 9, 8, 30, 9, 15, title: "1:1 mit Alex", tint: sea, location: "Meet — Raum Alpen")
        timed("demo-feb-109", 2026, 2, 10, 19, 0, 20, 30, title: "Jazz-Abend", tint: lilac, location: "Blue Note Keller")
        add(2026, 2, 11, CalendarEvent(id: "demo-feb-110", eventIdentifier: nil, day: 11, title: "Auto TÜV + Inspektion", tint: butter, location: "ATU Werkstatt", allDay: true))
        timed("demo-feb-110b", 2026, 2, 11, 14, 0, 15, 30, title: "Mietwagen abholen", tint: coral, location: "ATU Werkstatt")
        // Feb 12: sparse
        timed("demo-feb-112", 2026, 2, 13, 17, 30, 18, 30, title: "Therapie-Sitzung", tint: sky)
        add(2026, 2, 14, CalendarEvent(
            id: "demo-feb-002", eventIdentifier: nil, day: 14,
            startDate: date(2026, 2, 14, h: 10, min: 0),
            endDate: date(2026, 2, 14, h: 12, min: 30),
            title: "Valentinstag — Brunch", tint: peach, location: "Café Kranzler", allDay: false
        ))
        timed("demo-feb-002b", 2026, 2, 14, 18, 30, 20, 0, title: "Abendspaziergang am Rhein", tint: rose, location: "Rheinufer")
        timed("demo-feb-113", 2026, 2, 15, 14, 0, 15, 30, title: "Museum — Impressionisten", tint: lilac, location: "Städel Museum")
        timed("demo-feb-114", 2026, 2, 16, 11, 0, 12, 0, title: "Elternsprechtag", tint: coral, location: "Grundschule am Park")
        timed("demo-feb-115", 2026, 2, 17, 16, 0, 17, 0, title: "Gitarrenstunde", tint: sea)
        // Feb 18: sparse
        timed("demo-feb-117", 2026, 2, 19, 20, 0, 22, 30, title: "Eishockey — Heimspiel", tint: sky, location: "Eissporthalle")
        for day in 20 ... 22 {
            add(2026, 2, day, CalendarEvent(id: "demo-feb-ski-\(day)", eventIdentifier: nil, day: day, title: "Skiurlaub — Zillertal", tint: sky, allDay: true))
        }
        timed("demo-feb-ski21b", 2026, 2, 21, 17, 0, 18, 30, title: "Après-Ski — Fondue", tint: peach, location: "Berghütte")
        timed("demo-feb-118", 2026, 2, 23, 13, 0, 14, 0, title: "Mittagessen — Investoren", tint: peach, location: "Hafenhaus")
        timed("demo-feb-118b", 2026, 2, 23, 16, 30, 17, 30, title: "Besichtigung — neues Büro", tint: mint, location: "WeWork")
        // Feb 24: sparse
        add(2026, 2, 25, CalendarEvent(id: "demo-feb-120", eventIdentifier: nil, day: 25, title: "Steuererklärung vorbereiten", tint: rose, allDay: true))
        timed("demo-feb-121", 2026, 2, 26, 8, 0, 8, 30, title: "Flug nach Berlin", tint: lilac, location: "Gate B12")
        timed("demo-feb-122", 2026, 2, 27, 12, 30, 13, 30, title: "Design-Review", tint: coral, location: "Figma / HQ-4")
        add(2026, 2, 28, CalendarEvent(id: "demo-feb-123", eventIdentifier: nil, day: 28, title: "Winterschlussverkauf — letzter Tag", tint: butter, allDay: true))

        // MARK: März
        add(2026, 3, 1, CalendarEvent(id: "demo-mar-101", eventIdentifier: nil, day: 1, title: "Frühjahrs-Kleidertausch", tint: lilac, allDay: true))
        timed("demo-mar-101b", 2026, 3, 1, 14, 0, 15, 0, title: "Spende abgeben — Kleidung", tint: coral, location: "Caritas")
        timed("demo-mar-102", 2026, 3, 2, 9, 30, 10, 30, title: "All-Hands (hybrid)", tint: sea, location: "Town Hall A")
        timed("demo-mar-102b", 2026, 3, 2, 15, 0, 16, 0, title: "Design-Review — Nachbesprechung", tint: lilac, location: "Figma")
        timed("demo-mar-103", 2026, 3, 3, 17, 0, 18, 15, title: "Physiotherapie", tint: mint, location: "Praxis Bewegung")
        timed("demo-mar-104", 2026, 3, 4, 12, 0, 13, 0, title: "Lunch & Learn — SwiftUI", tint: peach, location: "Dev-Lounge")
        timed("demo-mar-104b", 2026, 3, 4, 18, 0, 19, 0, title: "Lauftreff — lockere 5 km", tint: sky, location: "Rheinufer")
        add(2026, 3, 5, CalendarEvent(id: "demo-mar-105", eventIdentifier: nil, day: 5, title: "Reisekosten einreichen", tint: butter, allDay: true))
        // Mar 6: sparse
        timed("demo-mar-107", 2026, 3, 7, 11, 0, 12, 30, title: "Brunch mit den Eltern", tint: rose, location: "Landhaus Krone")
        add(2026, 3, 8, CalendarEvent(
            id: "demo-mar-001", eventIdentifier: nil, day: 8,
            startDate: date(2026, 3, 8, h: 11, min: 0),
            endDate: date(2026, 3, 8, h: 13, min: 0),
            title: "Weltfrauentag — Familienkaffee", tint: lilac, location: "Zuhause", allDay: false
        ))
        timed("demo-mar-108", 2026, 3, 9, 14, 0, 15, 30, title: "Foto-Spaziergang", tint: coral, location: "Uferpromenade")
        timed("demo-mar-110", 2026, 3, 10, 8, 0, 9, 0, title: "Zahnreinigung", tint: sea, location: "Praxis Dr. Meier")
        timed("demo-mar-111", 2026, 3, 11, 19, 30, 21, 0, title: "Indie-Film im Kino", tint: lilac, location: "Programmkino")
        // Mar 12: sparse
        timed("demo-mar-113", 2026, 3, 13, 16, 0, 17, 30, title: "Friseur", tint: peach, location: "Salon M")
        timed("demo-mar-114", 2026, 3, 14, 9, 0, 11, 0, title: "Wochenmarkt + Kaffee", tint: mint, location: "Marktplatz")
        timed("demo-mar-114b", 2026, 3, 14, 15, 0, 16, 30, title: "Mittagspause + Wäsche", tint: butter)
        add(2026, 3, 15, CalendarEvent(
            id: "demo-mar-002", eventIdentifier: nil, day: 15,
            startDate: date(2026, 3, 15, h: 15, min: 30),
            endDate: date(2026, 3, 15, h: 16, min: 30),
            title: "Zahnarzt-Kontrolle", tint: mint, location: "Praxis Dr. Weber", allDay: false
        ))
        add(2026, 3, 16, CalendarEvent(id: "demo-mar-115", eventIdentifier: nil, day: 16, title: "Eigentümerversammlung", tint: sky, location: "Gemeindehaus", allDay: true))
        timed("demo-mar-116", 2026, 3, 17, 18, 0, 19, 30, title: "Badminton-Liga", tint: coral, location: "Sporthalle 2")
        // Mar 18: sparse
        timed("demo-mar-119", 2026, 3, 19, 7, 30, 8, 15, title: "Spinning", tint: rose, location: "FitX")
        timed("demo-mar-120", 2026, 3, 20, 13, 0, 14, 30, title: "Mittagessen — Mentor-Gespräch", tint: peach, location: "Kaffeerösterei")
        timed("demo-mar-120b", 2026, 3, 20, 17, 0, 18, 0, title: "Code-Review — Kalender-Widgets", tint: sea, location: "Zoom")
        add(2026, 3, 21, CalendarEvent(id: "demo-mar-121", eventIdentifier: nil, day: 21, title: "Frühlingsanfang — Wanderung", tint: mint, location: "Schwarzwald", allDay: true))
        timed("demo-mar-122", 2026, 3, 22, 15, 0, 16, 30, title: "Kindergeburtstag", tint: lilac, location: "Trampolinhalle")
        timed("demo-mar-122b", 2026, 3, 22, 10, 0, 11, 30, title: "Party-Aufbau (Deko)", tint: sky, location: "Trampolinhalle")
        timed("demo-mar-123", 2026, 3, 23, 9, 30, 10, 30, title: "Vertragsprüfung — Recht", tint: butter, location: "WeWork — 9. OG")
        // Mar 24: sparse
        timed("demo-mar-125", 2026, 3, 25, 11, 30, 12, 30, title: "Offene Sprechstunde", tint: coral, location: "Slack Huddle")
        timed("demo-mar-126", 2026, 3, 26, 17, 0, 18, 0, title: "Hundeschule", tint: sea, location: "Hundewiese Süd")
        timed("demo-mar-127", 2026, 3, 27, 8, 45, 9, 30, title: "Schule — Bringdienst", tint: peach)
        add(2026, 3, 28, CalendarEvent(id: "demo-mar-003", eventIdentifier: nil, day: 28, title: "Frühjahrsputz", tint: butter, allDay: true))
        timed("demo-mar-128", 2026, 3, 29, 14, 0, 15, 0, title: "Charity-Lauf — Startnummer abholen", tint: rose, location: "Messehalle")
        // Mar 30: sparse
        add(2026, 3, 31, CalendarEvent(id: "demo-mar-130", eventIdentifier: nil, day: 31, title: "Q1-Zusammenfassung fällig", tint: sky, allDay: true))

        // MARK: April (dicht — Haupt-Demo-Monat)
        add(2026, 4, 1, CalendarEvent(id: "demo-apr-101", eventIdentifier: nil, day: 1, title: "1. April — bitte keine Streiche", tint: butter, allDay: true))
        timed("demo-apr-101b", 2026, 4, 1, 11, 0, 11, 45, title: "Team-Streich-Nachbesprechung", tint: lilac, location: "Slack")
        timed("demo-apr-102", 2026, 4, 2, 9, 0, 10, 0, title: "Stand-up", tint: sea, location: "Zoom")
        timed("demo-apr-103", 2026, 4, 2, 15, 30, 16, 30, title: "Kaffee mit Nachbarin", tint: peach, location: "Terrasse")
        add(2026, 4, 3, CalendarEvent(
            id: "demo-apr-001", eventIdentifier: nil, day: 3,
            startDate: date(2026, 4, 3, h: 10, min: 0),
            endDate: date(2026, 4, 3, h: 11, min: 30),
            title: "Team-Stand-up & Roadmap", tint: sea, location: "Zoom", allDay: false
        ))
        timed("demo-apr-001b", 2026, 4, 3, 14, 0, 15, 30, title: "Roadmap — Stakeholder-Runde", tint: lilac, location: "Zoom")
        timed("demo-apr-104", 2026, 4, 4, 11, 0, 12, 30, title: "Oster-Brunch", tint: rose, location: "Landgasthof Sonne")
        timed("demo-apr-104b", 2026, 4, 4, 16, 0, 17, 30, title: "Ostereiersuche — Nachbarschaft", tint: mint, location: "Park")
        add(2026, 4, 5, CalendarEvent(
            id: "demo-apr-002", eventIdentifier: nil, day: 5,
            startDate: date(2026, 4, 5, h: 19, min: 30),
            endDate: date(2026, 4, 5, h: 22, min: 0),
            title: "Kammerkonzert", tint: lilac, location: "Philharmonie", allDay: false
        ))
        timed("demo-apr-005b", 2026, 4, 5, 10, 0, 11, 30, title: "Matinee — Familienfilm", tint: butter, location: "CineStar")
        // Apr 6: sparse
        timed("demo-apr-106", 2026, 4, 7, 18, 0, 19, 30, title: "Fußball-Nachholtraining", tint: coral, location: "Sportplatz Ost")
        timed("demo-apr-106b", 2026, 4, 7, 8, 0, 8, 45, title: "E-Mail-Block — Deep Work", tint: sea)
        timed("demo-apr-107", 2026, 4, 8, 12, 0, 12, 45, title: "Mittagsspaziergang", tint: sky)
        timed("demo-apr-108", 2026, 4, 9, 14, 0, 15, 30, title: "UX-Research-Sessions", tint: lilac, location: "Labor 2")
        timed("demo-apr-108b", 2026, 4, 9, 18, 0, 19, 0, title: "Prototyp-Feinschliff — Übergabe", tint: peach, location: "Labor 2")
        for day in 10 ... 11 {
            add(2026, 4, day, CalendarEvent(id: "demo-apr-messe-\(day)", eventIdentifier: nil, day: day, title: "Smart Cities Messe", tint: sky, allDay: true))
        }
        timed("demo-apr-messe11b", 2026, 4, 11, 17, 0, 18, 30, title: "Messe — Standabbau", tint: coral, location: "Halle C")
        // Apr 12: sparse
        timed("demo-apr-109", 2026, 4, 13, 10, 0, 11, 0, title: "Mitarbeitergespräche — Start", tint: butter, location: "HR-Kalender")
        timed("demo-apr-109b", 2026, 4, 13, 14, 30, 15, 45, title: "1:1 — Design-Leitung", tint: lilac, location: "Ruhiger Raum")
        timed("demo-apr-110", 2026, 4, 14, 19, 0, 20, 30, title: "Poetry Slam", tint: peach, location: "Literaturhaus")
        timed("demo-apr-111", 2026, 4, 15, 9, 30, 10, 45, title: "Architektur-Review", tint: sea, location: "War Room")
        timed("demo-apr-111b", 2026, 4, 15, 12, 0, 13, 0, title: "Mittagessen — Plattform-Team", tint: peach, location: "Kantine")
        timed("demo-apr-112", 2026, 4, 16, 16, 0, 17, 0, title: "Mietwagen-Rückgabe", tint: coral, location: "Flughafen")
        timed("demo-apr-112b", 2026, 4, 16, 10, 30, 11, 30, title: "Flugverspätung — Puffer", tint: butter, location: "Terminal-Lounge")
        timed("demo-apr-113", 2026, 4, 17, 11, 30, 12, 30, title: "Hautarzt", tint: mint, location: "Derma-Praxis")

        // 2026-04-18 (SampleData "heute")
        add(2026, 4, 18, CalendarEvent(
            id: "demo-apr-today-001", eventIdentifier: nil, day: 18,
            startDate: date(2026, 4, 18, h: 8, min: 0),
            endDate: date(2026, 4, 18, h: 9, min: 30),
            title: "Frühstück mit Maria", tint: peach, location: "Bäckerei Schmitt", allDay: false
        ))
        timed("demo-apr-today-progress", 2026, 4, 18, 10, 0, 20, 0, title: "App-Store-Feinschliff — Fokusblock", tint: sea, location: "Home Office")
        add(2026, 4, 18, CalendarEvent(
            id: "demo-apr-today-002", eventIdentifier: nil, day: 18,
            startDate: date(2026, 4, 18, h: 12, min: 30),
            endDate: date(2026, 4, 18, h: 13, min: 45),
            title: "Team-Mittagessen", tint: mint, location: "Osteria Due", allDay: false
        ))
        add(2026, 4, 18, CalendarEvent(id: "demo-apr-today-003", eventIdentifier: nil, day: 18, title: "Familientreffen (ganztägig)", tint: rose, location: "Garten der Großeltern", allDay: true))
        add(2026, 4, 18, CalendarEvent(
            id: "demo-apr-today-004", eventIdentifier: nil, day: 18,
            startDate: date(2026, 4, 18, h: 20, min: 15),
            endDate: date(2026, 4, 18, h: 23, min: 15),
            title: "Kino: Dune Part Two", tint: coral, location: "CineStar Innenstadt", allDay: false
        ))

        timed("demo-apr-114", 2026, 4, 19, 10, 0, 11, 30, title: "Sonntagslauf — locker", tint: mint, location: "Seerunde")
        timed("demo-apr-114b", 2026, 4, 19, 15, 0, 17, 0, title: "Meal Prep + Podcasts", tint: sky)
        timed("demo-apr-115", 2026, 4, 20, 13, 0, 14, 0, title: "Gehaltsfreigaben", tint: butter, location: "HR-Portal")
        timed("demo-apr-116", 2026, 4, 21, 17, 30, 18, 45, title: "Tennis-Doppel", tint: sky, location: "Vereinsplätze")
        timed("demo-apr-117", 2026, 4, 22, 8, 0, 8, 45, title: "Online-Check-in Erinnerung", tint: lilac)
        timed("demo-apr-118", 2026, 4, 23, 15, 0, 16, 30, title: "Podcast-Aufnahme", tint: peach, location: "Heimstudio")
        timed("demo-apr-118b", 2026, 4, 23, 19, 0, 20, 0, title: "Podcast-Rohschnitt", tint: lilac, location: "Heimstudio")
        // Apr 24: sparse
        add(2026, 4, 25, CalendarEvent(id: "demo-apr-004", eventIdentifier: nil, day: 25, title: "Tagesausflug — Bodensee", tint: sea, allDay: true))
        timed("demo-apr-004b", 2026, 4, 25, 8, 30, 9, 15, title: "Auto packen + Snacks", tint: butter)
        timed("demo-apr-120", 2026, 4, 26, 14, 0, 15, 0, title: "Pflanzen umtopfen", tint: rose, location: "Terrasse")
        timed("demo-apr-121", 2026, 4, 27, 9, 0, 10, 0, title: "IT-Sicherheitsschulung (jährlich)", tint: coral, location: "LMS")
        timed("demo-apr-122", 2026, 4, 28, 18, 0, 19, 15, title: "Brotback-Kurs: Sauerteig", tint: lilac, location: "VHS Küche")
        timed("demo-apr-123", 2026, 4, 29, 11, 0, 12, 0, title: "Anbieter-Demo — Analytics", tint: butter, location: "Zoom")
        timed("demo-apr-123b", 2026, 4, 29, 15, 30, 16, 30, title: "Anbieter-Demo — Nachbesprechung", tint: lilac, location: "Zoom")
        // Apr 30: sparse

        // MARK: Mai
        add(2026, 5, 1, CalendarEvent(id: "demo-may-001", eventIdentifier: nil, day: 1, title: "Tag der Arbeit — Stadtteilfest", tint: rose, location: "Stadtpark", allDay: true))
        timed("demo-may-001b", 2026, 5, 1, 8, 30, 9, 30, title: "Feststand — ehrenamtlicher Aufbau", tint: sea, location: "Stadtpark")
        timed("demo-may-101", 2026, 5, 2, 10, 0, 12, 0, title: "Flohmarkt-Aufbau", tint: peach, location: "Einfahrt")
        timed("demo-may-101b", 2026, 5, 2, 14, 0, 16, 0, title: "Flohmarkt — Abbau", tint: butter, location: "Einfahrt")
        timed("demo-may-102", 2026, 5, 3, 15, 30, 17, 0, title: "Klaviervorspiel", tint: lilac, location: "Musikschule")
        timed("demo-may-103", 2026, 5, 4, 9, 0, 10, 30, title: "Vorstandssitzung — Vorbereitung", tint: sea, location: "Sitzungsraum B")
        timed("demo-may-104", 2026, 5, 5, 12, 15, 13, 0, title: "Spargel-Mittagessen (Team)", tint: coral, location: "Gasthaus zum Ritter")
        timed("demo-may-104b", 2026, 5, 5, 16, 0, 17, 0, title: "Feierabend-Runde (optional)", tint: peach, location: "Biergarten")
        // May 6: sparse
        timed("demo-may-106", 2026, 5, 7, 18, 30, 20, 0, title: "Gemeindechor", tint: sky, location: "Alte Kirche")
        timed("demo-may-106b", 2026, 5, 7, 12, 30, 13, 15, title: "Chormappe — Noten abholen", tint: lilac, location: "Alte Kirche")
        timed("demo-may-107", 2026, 5, 8, 14, 0, 15, 30, title: "1:1 — Karrieregespräch", tint: butter, location: "Kaffeerösterei")
        add(2026, 5, 9, CalendarEvent(
            id: "demo-may-002", eventIdentifier: nil, day: 9,
            startDate: date(2026, 5, 9, h: 10, min: 0),
            endDate: date(2026, 5, 9, h: 14, min: 0),
            title: "Muttertag — Brunch", tint: peach, location: "Hotel Atlantik", allDay: false
        ))
        timed("demo-may-002b", 2026, 5, 9, 8, 0, 9, 0, title: "Blumen + Karte besorgen", tint: rose, location: "Blumenladen")
        add(2026, 5, 10, CalendarEvent(id: "demo-may-108", eventIdentifier: nil, day: 10, title: "Garten bepflanzen", tint: mint, allDay: true))
        timed("demo-may-108b", 2026, 5, 10, 16, 0, 17, 30, title: "Neue Beete gießen", tint: sea, location: "Garten")
        timed("demo-may-109", 2026, 5, 11, 16, 0, 17, 30, title: "Zahnarzt — Kontroll-Röntgen", tint: sea, location: "Praxis Dr. Meier")
        // May 12: sparse
        timed("demo-may-111", 2026, 5, 13, 19, 0, 21, 30, title: "Fußball-Abend — Bundesliga", tint: sky, location: "Stadion")
        timed("demo-may-112", 2026, 5, 14, 8, 30, 9, 30, title: "Lesepate — Schule", tint: rose, location: "Raum 204")
        timed("demo-may-113", 2026, 5, 15, 13, 30, 14, 45, title: "Design-System-Workshop", tint: coral, location: "Design-Labor")
        timed("demo-may-114", 2026, 5, 16, 10, 30, 11, 45, title: "Wochenmarkt + Blumen", tint: peach, location: "Altstadt")
        timed("demo-may-115", 2026, 5, 17, 17, 0, 18, 30, title: "Kickboxen", tint: butter, location: "FitX")
        timed("demo-may-115b", 2026, 5, 17, 8, 30, 9, 15, title: "Dehnen + Mobilität", tint: mint, location: "Zuhause")
        // May 18: sparse
        timed("demo-may-117", 2026, 5, 19, 9, 15, 10, 0, title: "Flüge buchen — Sommerurlaub", tint: lilac)
        add(2026, 5, 20, CalendarEvent(id: "demo-may-003", eventIdentifier: nil, day: 20, title: "Release-Deadline — Kalender-App", tint: lilac, allDay: true))
        timed("demo-may-003b", 2026, 5, 20, 10, 0, 10, 45, title: "Release-Checkliste — Endkontrolle", tint: coral, location: "Zoom")
        timed("demo-may-118", 2026, 5, 21, 15, 0, 16, 0, title: "Team-Retro", tint: sea, location: "Miro")
        timed("demo-may-118b", 2026, 5, 21, 9, 30, 10, 15, title: "Retro-Vorbereitung — Notizen", tint: butter)
        timed("demo-may-119", 2026, 5, 22, 20, 0, 22, 0, title: "Comedy-Abend", tint: peach, location: "Quatsch Comedy Club")
        add(2026, 5, 23, CalendarEvent(id: "demo-may-120", eventIdentifier: nil, day: 23, title: "Pfingst-Wochenende — Camping", tint: sky, location: "Waldsee", allDay: true))
        timed("demo-may-120b", 2026, 5, 23, 17, 0, 18, 30, title: "Lagerfeuer + Stockbrot", tint: peach, location: "Waldsee")
        // May 24: sparse
        timed("demo-may-122", 2026, 5, 25, 10, 0, 11, 30, title: "Leih-Ausrüstung zurückgeben", tint: rose, location: "Outdoor-Laden")
        timed("demo-may-123", 2026, 5, 26, 14, 30, 15, 45, title: "Therapie", tint: mint)
        timed("demo-may-124", 2026, 5, 27, 8, 0, 9, 0, title: "All-Hands (EMEA)", tint: butter, location: "Zoom")
        timed("demo-may-125", 2026, 5, 28, 18, 0, 19, 30, title: "Date Night", tint: lilac, location: "Sushi Omakase")
        timed("demo-may-126", 2026, 5, 29, 12, 0, 13, 0, title: "Mittagessen — Investoren-Update", tint: sea, location: "Hafenhaus")
        timed("demo-may-126b", 2026, 5, 29, 15, 30, 16, 30, title: "Investoren — Follow-up-Mails", tint: lilac)
        // May 30: sparse
        add(2026, 5, 31, CalendarEvent(id: "demo-may-127", eventIdentifier: nil, day: 31, title: "Monatliches Foto-Backup", tint: sky, allDay: true))
        timed("demo-may-127b", 2026, 5, 31, 18, 0, 18, 45, title: "iCloud-Backup prüfen", tint: mint)

        // MARK: Juni
        timed("demo-jun-101", 2026, 6, 1, 9, 30, 10, 30, title: "OKR-Bewertung", tint: butter, location: "Notion")
        timed("demo-jun-101b", 2026, 6, 1, 14, 0, 15, 0, title: "OKRs — Freigabe Vorgesetzte", tint: sea, location: "Zoom")
        timed("demo-jun-102", 2026, 6, 2, 17, 0, 18, 30, title: "Schwimmkurs — Kinder", tint: sea, location: "Schwimmbad")
        timed("demo-jun-103", 2026, 6, 3, 12, 30, 13, 30, title: "Lunch & Learn — Datenschutz", tint: lilac, location: "Zoom")
        timed("demo-jun-103b", 2026, 6, 3, 16, 0, 16, 45, title: "DSGVO-Checkliste — Ordner", tint: coral, location: "Drive")
        timed("demo-jun-104", 2026, 6, 4, 19, 30, 21, 0, title: "Open-Air-Kino", tint: peach, location: "Amphitheater im Park")
        timed("demo-jun-104b", 2026, 6, 4, 17, 0, 18, 30, title: "Picknickdecke + Snacks", tint: mint, location: "Amphitheater im Park")
        add(2026, 6, 5, CalendarEvent(id: "demo-jun-105", eventIdentifier: nil, day: 5, title: "Garage ausmisten", tint: coral, allDay: true))
        timed("demo-jun-105b", 2026, 6, 5, 10, 0, 12, 0, title: "Wertstoffhof — erste Ladung", tint: butter, location: "Recyclinghof")
        // Jun 6: sparse
        timed("demo-jun-107", 2026, 6, 7, 15, 0, 16, 30, title: "Vatertag — Grillen", tint: rose, location: "Garten vom Onkel")
        timed("demo-jun-108", 2026, 6, 8, 10, 0, 11, 0, title: "Bereitschafts-Übergabe", tint: sky, location: "PagerDuty")
        timed("demo-jun-109", 2026, 6, 9, 13, 0, 14, 30, title: "Depot-Besprechung", tint: butter, location: "Berater-Büro")
        timed("demo-jun-110", 2026, 6, 10, 18, 0, 19, 15, title: "Kletterhalle", tint: coral, location: "Vertical Edge")
        timed("demo-jun-111", 2026, 6, 11, 11, 30, 12, 45, title: "Mittagessen — neuer PM", tint: peach, location: "Dachterrassen-Café")
        timed("demo-jun-111b", 2026, 6, 11, 9, 0, 9, 45, title: "Vorab-Lektüre — PRD v3", tint: lilac, location: "Notion")
        // Jun 12: sparse
        add(2026, 6, 13, CalendarEvent(id: "demo-jun-113", eventIdentifier: nil, day: 13, title: "Strand-Wochenende", tint: sky, location: "Ostsee-Pension", allDay: true))
        timed("demo-jun-113b", 2026, 6, 13, 17, 0, 19, 0, title: "Sonnenuntergang — Strandspaziergang", tint: coral, location: "Ostsee-Pension")
        timed("demo-jun-114", 2026, 6, 14, 10, 0, 11, 30, title: "Brunch vor Abreise", tint: mint, location: "Ostsee-Pension")
        timed("demo-jun-115", 2026, 6, 15, 16, 0, 17, 0, title: "Autowäsche + Pflege", tint: sea, location: "Waschstraße")
        timed("demo-jun-116", 2026, 6, 16, 9, 0, 10, 30, title: "Barrierefreiheits-Audit", tint: rose, location: "Testlabor")
        timed("demo-jun-117", 2026, 6, 17, 14, 0, 15, 30, title: "Spenden-Abgabe", tint: butter, location: "Caritas-Lager")
        timed("demo-jun-117b", 2026, 6, 17, 10, 0, 11, 0, title: "Spendenkartons sortieren", tint: mint, location: "Garage")
        // Jun 18: sparse
        timed("demo-jun-119", 2026, 6, 19, 12, 0, 13, 0, title: "Praktikanten-Präsentationen", tint: coral, location: "Town-Hall-Stream")
        timed("demo-jun-119b", 2026, 6, 19, 15, 30, 16, 30, title: "Praktikanten-Fragerunde", tint: sea, location: "Slack Huddle")
        timed("demo-jun-120", 2026, 6, 20, 8, 45, 10, 15, title: "Gartenarbeit-Aktion", tint: peach, location: "Vorgarten")
        add(2026, 6, 21, CalendarEvent(
            id: "demo-jun-001", eventIdentifier: nil, day: 21,
            startDate: date(2026, 6, 21, h: 18, min: 0),
            endDate: date(2026, 6, 21, h: 22, min: 30),
            title: "Sommersonnenwende — Grillfest", tint: coral, location: "Hinterhof-Terrasse", allDay: false
        ))
        timed("demo-jun-121", 2026, 6, 22, 9, 30, 10, 45, title: "Sicherheits-Review — Anbieter", tint: sea, location: "Zoom")
        timed("demo-jun-122", 2026, 6, 23, 17, 30, 18, 45, title: "Gesundheitscheck — jährlich", tint: mint, location: "Hausarztpraxis")
        // Jun 24: sparse
        timed("demo-jun-124", 2026, 6, 25, 19, 0, 20, 30, title: "Bürgerversammlung", tint: butter, location: "Aula Gymnasium")
        timed("demo-jun-124b", 2026, 6, 25, 12, 0, 13, 0, title: "Bürgerversammlung — Vorbereitung", tint: lilac)
        timed("demo-jun-125", 2026, 6, 26, 11, 0, 12, 30, title: "Quartalsplanung — Entwurf", tint: lilac, location: "Notion / FigJam")
        timed("demo-jun-126", 2026, 6, 27, 15, 0, 16, 30, title: "Trödelmarkt", tint: peach, location: "Messeplatz")
        add(2026, 6, 28, CalendarEvent(id: "demo-jun-002", eventIdentifier: nil, day: 28, title: "Hochzeit — Lisa & Thomas", tint: rose, location: "Weingut Rheingau", allDay: true))
        timed("demo-jun-002b", 2026, 6, 28, 8, 0, 9, 30, title: "Hochzeit — Friseur & Make-up", tint: peach, location: "Suite im Weingut")
        timed("demo-jun-127", 2026, 6, 29, 10, 0, 11, 0, title: "Nach-Hochzeits-Brunch (Familie)", tint: mint, location: "Weingut-Terrasse")
        timed("demo-jun-127b", 2026, 6, 29, 14, 0, 15, 30, title: "Dankes-Karten schreiben", tint: butter, location: "Hotellobby")
        // Jun 30: sparse

        sortedMap(&out)
        return out
    }
    // swiftlint:enable function_body_length
}
