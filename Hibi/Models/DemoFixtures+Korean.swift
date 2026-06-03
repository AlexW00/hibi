import Foundation
import SwiftUI

extension DemoFixtures {
    // swiftlint:disable function_body_length
    static func makeKoreanEvents() -> EventMap {
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

        // MARK: 2월
        add(2026, 2, 1, CalendarEvent(id: "demo-feb-101", eventIdentifier: nil, day: 1, title: "월간 예산 점검", tint: butter, allDay: true))
        timed("demo-feb-101b", 2026, 2, 1, 15, 0, 15, 45, title: "분기 계획 — 재무", tint: sea, location: "Google Meet")
        timed("demo-feb-102", 2026, 2, 2, 9, 0, 9, 45, title: "아침 요가", tint: mint, location: "한남동 요가원", recurring: true)
        add(2026, 2, 3, CalendarEvent(id: "demo-feb-001", eventIdentifier: nil, day: 3, title: "입춘", tint: rose, allDay: true))
        timed("demo-feb-001b", 2026, 2, 3, 19, 0, 22, 0, title: "가족 저녁 식사", tint: lilac, location: "집")
        timed("demo-feb-103", 2026, 2, 4, 12, 0, 12, 30, title: "치과 — 스케일링", tint: sea, location: "미소 치과")
        timed("demo-feb-104", 2026, 2, 5, 18, 0, 19, 30, title: "쿠킹 클래스: 칼국수", tint: peach, location: "쿠킹 스튜디오")
        // 2/6: sparse
        timed("demo-feb-106", 2026, 2, 7, 10, 30, 11, 30, title: "독서 모임", tint: sky, location: "교보문고")
        timed("demo-feb-106b", 2026, 2, 7, 16, 0, 17, 0, title: "장보기 + 밑반찬", tint: butter, location: "마켓컬리")
        timed("demo-feb-107", 2026, 2, 8, 15, 0, 16, 0, title: "아이 축구 연습", tint: coral, location: "잠실 운동장")
        timed("demo-feb-108", 2026, 2, 9, 8, 30, 9, 15, title: "1on1 미팅", tint: sea, location: "Google Meet — 회의실A", recurring: true)
        timed("demo-feb-109", 2026, 2, 10, 19, 0, 20, 30, title: "재즈 라이브", tint: lilac, location: "올댓재즈")
        add(2026, 2, 11, CalendarEvent(id: "demo-feb-110", eventIdentifier: nil, day: 11, title: "팀 워크숍", tint: butter, allDay: true))
        timed("demo-feb-110b", 2026, 2, 11, 14, 0, 15, 30, title: "차량 정비 찾기", tint: coral, location: "정비소")
        // 2/12: sparse
        timed("demo-feb-112", 2026, 2, 13, 17, 30, 18, 30, title: "심리 상담", tint: sky, recurring: true)
        add(2026, 2, 14, CalendarEvent(
            id: "demo-feb-002", eventIdentifier: nil, day: 14,
            startDate: date(2026, 2, 14, h: 10, min: 0),
            endDate: date(2026, 2, 14, h: 12, min: 30),
            title: "발렌타인 — 브런치", tint: peach, location: "한남동 레스토랑", allDay: false
        ))
        timed("demo-feb-002b", 2026, 2, 14, 18, 30, 20, 0, title: "노을 산책 — 한강", tint: rose, location: "반포 한강공원")
        timed("demo-feb-113", 2026, 2, 15, 14, 0, 15, 30, title: "미술관 — 기획전", tint: lilac, location: "국립현대미술관")
        timed("demo-feb-114", 2026, 2, 16, 11, 0, 12, 0, title: "학부모 상담", tint: coral, location: "초등학교")
        timed("demo-feb-115", 2026, 2, 17, 16, 0, 17, 0, title: "기타 레슨", tint: sea)
        // 2/18: sparse
        timed("demo-feb-117", 2026, 2, 19, 20, 0, 22, 30, title: "농구 관람", tint: sky, location: "잠실 실내체육관")
        for day in 20 ... 22 {
            add(2026, 2, day, CalendarEvent(id: "demo-feb-onsen-\(day)", eventIdentifier: nil, day: day, title: "설 연휴 — 귀성", tint: sky, allDay: true))
        }
        timed("demo-feb-onsen21b", 2026, 2, 21, 17, 0, 18, 30, title: "설 차례 — 온 가족", tint: peach, location: "본가")
        timed("demo-feb-118", 2026, 2, 23, 13, 0, 14, 0, title: "점심 — 투자자", tint: peach, location: "여의도 레스토랑")
        timed("demo-feb-118b", 2026, 2, 23, 16, 30, 17, 30, title: "사무실 보기 — 신규", tint: mint, location: "WeWork 강남")
        // 2/24: sparse
        add(2026, 2, 25, CalendarEvent(id: "demo-feb-120", eventIdentifier: nil, day: 25, title: "연말정산 준비", tint: rose, allDay: true))
        timed("demo-feb-121", 2026, 2, 26, 8, 0, 8, 30, title: "KTX 부산행", tint: lilac, location: "서울역")
        timed("demo-feb-122", 2026, 2, 27, 12, 30, 13, 30, title: "디자인 리뷰", tint: coral, location: "Figma / 본사")
        add(2026, 2, 28, CalendarEvent(id: "demo-feb-123", eventIdentifier: nil, day: 28, title: "겨울 세일 마지막 날", tint: butter, allDay: true))

        // MARK: 3월
        add(2026, 3, 1, CalendarEvent(id: "demo-mar-101", eventIdentifier: nil, day: 1, title: "삼일절 — 봄맞이 정리", tint: lilac, allDay: true))
        timed("demo-mar-101b", 2026, 3, 1, 14, 0, 15, 0, title: "헌 옷 기부", tint: coral, location: "의류 수거함")
        timed("demo-mar-102", 2026, 3, 2, 9, 30, 10, 30, title: "전사 미팅", tint: sea, location: "강당")
        timed("demo-mar-102b", 2026, 3, 2, 15, 0, 16, 0, title: "디자인 리뷰 — 후속", tint: lilac, location: "Figma")
        add(2026, 3, 3, CalendarEvent(id: "demo-mar-hina", eventIdentifier: nil, day: 3, title: "정월대보름", tint: rose, allDay: true))
        timed("demo-mar-103", 2026, 3, 3, 17, 0, 18, 15, title: "오곡밥 짓기", tint: mint, location: "집")
        timed("demo-mar-104", 2026, 3, 4, 12, 0, 13, 0, title: "점심 세미나 — SwiftUI", tint: peach, location: "개발 라운지")
        timed("demo-mar-104b", 2026, 3, 4, 18, 0, 19, 0, title: "야간 러닝 — 올림픽공원", tint: sky, location: "올림픽공원")
        add(2026, 3, 5, CalendarEvent(id: "demo-mar-105", eventIdentifier: nil, day: 5, title: "경비 정산 제출", tint: butter, allDay: true))
        // 3/6: sparse
        timed("demo-mar-107", 2026, 3, 7, 11, 0, 12, 30, title: "부모님과 브런치", tint: rose, location: "삼청동 레스토랑")
        add(2026, 3, 8, CalendarEvent(
            id: "demo-mar-001", eventIdentifier: nil, day: 8,
            startDate: date(2026, 3, 8, h: 11, min: 0),
            endDate: date(2026, 3, 8, h: 13, min: 0),
            title: "세계 여성의 날 — 가족 티타임", tint: lilac, location: "집", allDay: false
        ))
        timed("demo-mar-108", 2026, 3, 9, 14, 0, 15, 30, title: "거리 스냅", tint: coral, location: "익선동")
        timed("demo-mar-110", 2026, 3, 10, 8, 0, 9, 0, title: "치과 — 정기 검진", tint: sea, location: "미소 치과")
        timed("demo-mar-111", 2026, 3, 11, 19, 30, 21, 0, title: "예술영화관 — 영화", tint: lilac, location: "광화문 시네큐브")
        // 3/12: sparse
        timed("demo-mar-113", 2026, 3, 13, 16, 0, 17, 30, title: "미용실", tint: peach, location: "청담 헤어")
        timed("demo-mar-114", 2026, 3, 14, 9, 0, 11, 0, title: "화이트데이 — 선물 고르기", tint: mint, location: "신세계백화점")
        timed("demo-mar-114b", 2026, 3, 14, 15, 0, 16, 30, title: "낮잠 + 빨래", tint: butter)
        add(2026, 3, 15, CalendarEvent(
            id: "demo-mar-002", eventIdentifier: nil, day: 15,
            startDate: date(2026, 3, 15, h: 15, min: 30),
            endDate: date(2026, 3, 15, h: 16, min: 30),
            title: "구강 검진", tint: mint, location: "미소 치과", allDay: false
        ))
        add(2026, 3, 16, CalendarEvent(id: "demo-mar-115", eventIdentifier: nil, day: 16, title: "아파트 입주자 회의", tint: sky, location: "관리사무소", allDay: true))
        timed("demo-mar-116", 2026, 3, 17, 18, 0, 19, 30, title: "테니스 레슨", tint: coral, location: "3번 코트")
        // 3/18: sparse
        timed("demo-mar-119", 2026, 3, 19, 7, 30, 8, 15, title: "스피닝", tint: rose, location: "애니타임 피트니스")
        timed("demo-mar-120", 2026, 3, 20, 13, 0, 14, 30, title: "점심 — 멘토 커피", tint: peach, location: "블루보틀")
        timed("demo-mar-120b", 2026, 3, 20, 17, 0, 18, 0, title: "코드 리뷰 — 캘린더 위젯", tint: sea, location: "Google Meet")
        add(2026, 3, 21, CalendarEvent(id: "demo-mar-121", eventIdentifier: nil, day: 21, title: "춘분 — 북한산 등산", tint: mint, location: "북한산", allDay: true))
        timed("demo-mar-122", 2026, 3, 22, 15, 0, 16, 30, title: "아이 생일 파티", tint: lilac, location: "키즈파크")
        timed("demo-mar-122b", 2026, 3, 22, 10, 0, 11, 30, title: "파티 준비 (꾸미기)", tint: sky, location: "키즈파크")
        timed("demo-mar-123", 2026, 3, 23, 9, 30, 10, 30, title: "법무 검토 — 계약서", tint: butter, location: "WeWork 을지로")
        // 3/24: sparse
        timed("demo-mar-125", 2026, 3, 25, 11, 30, 12, 30, title: "오피스 아워", tint: coral, location: "Slack 허들")
        timed("demo-mar-126", 2026, 3, 26, 17, 0, 18, 0, title: "강아지 훈련 교실", tint: sea, location: "서울숲")
        timed("demo-mar-127", 2026, 3, 27, 8, 45, 9, 30, title: "아이 등교 도우미", tint: peach)
        add(2026, 3, 28, CalendarEvent(id: "demo-mar-003", eventIdentifier: nil, day: 28, title: "대청소 — 봄맞이", tint: butter, allDay: true))
        timed("demo-mar-128", 2026, 3, 29, 14, 0, 15, 0, title: "자선 마라톤 — 배번 수령", tint: rose, location: "서울월드컵경기장")
        // 3/30: sparse
        add(2026, 3, 31, CalendarEvent(id: "demo-mar-130", eventIdentifier: nil, day: 31, title: "Q1 결산 메모 제출", tint: sky, allDay: true))

        // MARK: 4월 (풍성 — 메인 데모 월)
        add(2026, 4, 1, CalendarEvent(id: "demo-apr-101", eventIdentifier: nil, day: 1, title: "새 회계연도 시작", tint: butter, allDay: true))
        timed("demo-apr-101b", 2026, 4, 1, 11, 0, 11, 45, title: "신입 환영 점심", tint: lilac, location: "구내식당")
        timed("demo-apr-102", 2026, 4, 2, 9, 0, 10, 0, title: "데일리 스크럼", tint: sea, location: "Google Meet")
        timed("demo-apr-103", 2026, 4, 2, 15, 30, 16, 30, title: "옆집 할머니와 차 한잔", tint: peach, location: "마당")
        add(2026, 4, 3, CalendarEvent(
            id: "demo-apr-001", eventIdentifier: nil, day: 3,
            startDate: date(2026, 4, 3, h: 10, min: 0),
            endDate: date(2026, 4, 3, h: 11, min: 30),
            title: "팀 스탠드업 & 로드맵", tint: sea, location: "Google Meet", allDay: false
        ))
        timed("demo-apr-001b", 2026, 4, 3, 14, 0, 15, 30, title: "로드맵 — 이해관계자 Q&A", tint: lilac, location: "Google Meet")
        timed("demo-apr-104", 2026, 4, 4, 11, 0, 12, 30, title: "벚꽃 브런치", tint: rose, location: "여의도 윤중로")
        timed("demo-apr-104b", 2026, 4, 4, 16, 0, 17, 30, title: "벚꽃놀이 — 자리 맡기", tint: mint, location: "석촌호수")
        add(2026, 4, 5, CalendarEvent(
            id: "demo-apr-002", eventIdentifier: nil, day: 5,
            startDate: date(2026, 4, 5, h: 19, min: 30),
            endDate: date(2026, 4, 5, h: 22, min: 0),
            title: "클래식 콘서트", tint: lilac, location: "예술의전당", allDay: false
        ))
        timed("demo-apr-005b", 2026, 4, 5, 10, 0, 11, 30, title: "영화 — 가족과", tint: butter, location: "CGV")
        // 4/6: sparse
        timed("demo-apr-106", 2026, 4, 7, 18, 0, 19, 30, title: "축구 보강 훈련", tint: coral, location: "잠실 운동장")
        timed("demo-apr-106b", 2026, 4, 7, 8, 0, 8, 45, title: "메일 정리 — 집중 시간", tint: sea)
        timed("demo-apr-107", 2026, 4, 8, 12, 0, 12, 45, title: "점심 산책", tint: sky)
        timed("demo-apr-108", 2026, 4, 9, 14, 0, 15, 30, title: "UX 리서치 세션", tint: lilac, location: "랩2")
        timed("demo-apr-108b", 2026, 4, 9, 18, 0, 19, 0, title: "프로토타입 수정 — 핸드오프", tint: peach, location: "랩2")
        for day in 10 ... 11 {
            add(2026, 4, day, CalendarEvent(id: "demo-apr-tech-\(day)", eventIdentifier: nil, day: day, title: "테크 컨퍼런스", tint: sky, allDay: true))
        }
        timed("demo-apr-tech11b", 2026, 4, 11, 17, 0, 18, 30, title: "컨퍼런스 — 부스 철수", tint: coral, location: "코엑스")
        // 4/12: sparse
        timed("demo-apr-109", 2026, 4, 13, 10, 0, 11, 0, title: "인사 평가 — 시작", tint: butter, location: "HR 시스템")
        timed("demo-apr-109b", 2026, 4, 13, 14, 30, 15, 45, title: "1on1 — 디자인 리드", tint: lilac, location: "조용한 방")
        timed("demo-apr-110", 2026, 4, 14, 19, 0, 20, 30, title: "스탠드업 코미디", tint: peach, location: "코미디 극장")
        timed("demo-apr-111", 2026, 4, 15, 9, 30, 10, 45, title: "아키텍처 리뷰", tint: sea, location: "워룸")
        timed("demo-apr-111b", 2026, 4, 15, 12, 0, 13, 0, title: "점심 — 플랫폼 팀", tint: peach, location: "사옥 카페")
        timed("demo-apr-112", 2026, 4, 16, 16, 0, 17, 0, title: "렌터카 반납", tint: coral, location: "공항")
        timed("demo-apr-112b", 2026, 4, 16, 10, 30, 11, 30, title: "항공편 지연 버퍼", tint: butter, location: "라운지")
        timed("demo-apr-113", 2026, 4, 17, 11, 30, 12, 30, title: "피부과", tint: mint, location: "피부과 의원")

        // 2026-04-18 (SampleData "오늘")
        add(2026, 4, 18, CalendarEvent(
            id: "demo-apr-today-001", eventIdentifier: nil, day: 18,
            startDate: date(2026, 4, 18, h: 8, min: 0),
            endDate: date(2026, 4, 18, h: 9, min: 30),
            title: "아침 — 미경과", tint: peach, location: "밀밭 베이커리", allDay: false
        ))
        timed("demo-apr-today-progress", 2026, 4, 18, 10, 0, 20, 0, title: "App Store 마무리 — 집중 블록", tint: sea, location: "홈 오피스", recurring: true)
        add(2026, 4, 18, CalendarEvent(
            id: "demo-apr-today-002", eventIdentifier: nil, day: 18,
            startDate: date(2026, 4, 18, h: 12, min: 30),
            endDate: date(2026, 4, 18, h: 13, min: 45),
            title: "팀 점심", tint: mint, location: "트라토리아", allDay: false,
            isRecurring: true
        ))
        add(2026, 4, 18, CalendarEvent(id: "demo-apr-today-003", eventIdentifier: nil, day: 18, title: "가족 모임 (종일)", tint: rose, location: "조부모님 댁", allDay: true))
        add(2026, 4, 18, CalendarEvent(
            id: "demo-apr-today-004", eventIdentifier: nil, day: 18,
            startDate: date(2026, 4, 18, h: 20, min: 15),
            endDate: date(2026, 4, 18, h: 23, min: 15),
            title: "영화: 듄 파트2", tint: coral, location: "CGV 용산 IMAX", allDay: false
        ))

        timed("demo-apr-114", 2026, 4, 19, 10, 0, 11, 30, title: "일요일 조깅", tint: mint, location: "올림픽공원")
        timed("demo-apr-114b", 2026, 4, 19, 15, 0, 17, 0, title: "밑반찬 + 팟캐스트", tint: sky)
        timed("demo-apr-115", 2026, 4, 20, 13, 0, 14, 0, title: "급여 승인", tint: butter, location: "회계 포털")
        timed("demo-apr-116", 2026, 4, 21, 17, 30, 18, 45, title: "테니스 복식", tint: sky, location: "코트")
        timed("demo-apr-117", 2026, 4, 22, 8, 0, 8, 45, title: "항공편 체크인", tint: lilac)
        timed("demo-apr-118", 2026, 4, 23, 15, 0, 16, 30, title: "팟캐스트 녹음", tint: peach, location: "홈 스튜디오")
        timed("demo-apr-118b", 2026, 4, 23, 19, 0, 20, 0, title: "팟캐스트 가편집", tint: lilac, location: "홈 스튜디오")
        // 4/24: sparse
        add(2026, 4, 25, CalendarEvent(id: "demo-apr-004", eventIdentifier: nil, day: 25, title: "당일치기 — 전주", tint: sea, allDay: true))
        timed("demo-apr-004b", 2026, 4, 25, 8, 30, 9, 15, title: "도시락 + 준비", tint: butter)
        timed("demo-apr-120", 2026, 4, 26, 14, 0, 15, 0, title: "분갈이 파티", tint: rose, location: "베란다")
        timed("demo-apr-121", 2026, 4, 27, 9, 0, 10, 0, title: "보안 교육 (연례)", tint: coral, location: "LMS")
        timed("demo-apr-122", 2026, 4, 28, 18, 0, 19, 15, title: "베이킹 클래스: 캄파뉴", tint: lilac, location: "베이킹 스튜디오")
        add(2026, 4, 29, CalendarEvent(id: "demo-apr-showa", eventIdentifier: nil, day: 29, title: "팀 워크숍", tint: butter, allDay: true))
        timed("demo-apr-123", 2026, 4, 29, 11, 0, 12, 0, title: "벤더 데모 — 분석 툴", tint: sea, location: "Google Meet")
        // 4/30: sparse

        // MARK: 5월
        add(2026, 5, 1, CalendarEvent(id: "demo-may-001", eventIdentifier: nil, day: 1, title: "근로자의 날", tint: rose, allDay: true))
        timed("demo-may-001b", 2026, 5, 1, 8, 30, 9, 30, title: "지역 봉사 준비", tint: sea, location: "주민센터")
        timed("demo-may-101", 2026, 5, 2, 10, 0, 12, 0, title: "플리마켓 준비", tint: peach, location: "주차장")
        timed("demo-may-101b", 2026, 5, 2, 14, 0, 16, 0, title: "플리마켓 정리", tint: butter, location: "주차장")
        add(2026, 5, 3, CalendarEvent(id: "demo-may-kenpo", eventIdentifier: nil, day: 3, title: "주말 나들이 — 근교", tint: lilac, allDay: true))
        timed("demo-may-102", 2026, 5, 3, 15, 30, 17, 0, title: "피아노 발표회", tint: sky, location: "음악학원")
        add(2026, 5, 4, CalendarEvent(id: "demo-may-midori", eventIdentifier: nil, day: 4, title: "봄나들이 — 교외", tint: mint, allDay: true))
        timed("demo-may-103", 2026, 5, 4, 9, 0, 10, 30, title: "이사회 준비", tint: sea, location: "B 회의실")
        add(2026, 5, 5, CalendarEvent(id: "demo-may-kodomo", eventIdentifier: nil, day: 5, title: "어린이날", tint: coral, allDay: true))
        timed("demo-may-104", 2026, 5, 5, 12, 15, 13, 0, title: "아이와 나들이", tint: peach, location: "어린이대공원")
        timed("demo-may-104b", 2026, 5, 5, 16, 0, 17, 0, title: "강변 산책", tint: sky, location: "한강공원")
        // 5/6: sparse (대체공휴일)
        timed("demo-may-106", 2026, 5, 7, 18, 30, 20, 0, title: "합창단 연습", tint: sky, location: "문화센터")
        timed("demo-may-106b", 2026, 5, 7, 12, 30, 13, 15, title: "합창 악보 받기", tint: lilac, location: "문화센터")
        timed("demo-may-107", 2026, 5, 8, 14, 0, 15, 30, title: "1on1 — 커리어 상담", tint: butter, location: "커피 랩")
        add(2026, 5, 9, CalendarEvent(
            id: "demo-may-002", eventIdentifier: nil, day: 9,
            startDate: date(2026, 5, 9, h: 10, min: 0),
            endDate: date(2026, 5, 9, h: 14, min: 0),
            title: "어버이날 브런치", tint: peach, location: "호텔 신라", allDay: false
        ))
        timed("demo-may-002b", 2026, 5, 9, 8, 0, 9, 0, title: "꽃 + 카네이션 사기", tint: rose, location: "양재 꽃시장")
        add(2026, 5, 10, CalendarEvent(id: "demo-may-108", eventIdentifier: nil, day: 10, title: "베란다 텃밭 가꾸기", tint: mint, allDay: true))
        timed("demo-may-108b", 2026, 5, 10, 16, 0, 17, 30, title: "새 화단 물주기", tint: sea, location: "베란다")
        timed("demo-may-109", 2026, 5, 11, 16, 0, 17, 30, title: "치과 — 재진", tint: sea, location: "미소 치과")
        // 5/12: sparse
        timed("demo-may-111", 2026, 5, 13, 19, 0, 21, 30, title: "야구 관람", tint: sky, location: "잠실 야구장")
        timed("demo-may-112", 2026, 5, 14, 8, 30, 9, 30, title: "그림책 읽어주기 봉사", tint: rose, location: "204 교실")
        timed("demo-may-113", 2026, 5, 15, 13, 30, 14, 45, title: "디자인 시스템 워크숍", tint: coral, location: "디자인 랩")
        timed("demo-may-114", 2026, 5, 16, 10, 30, 11, 45, title: "아침 장 + 꽃", tint: peach, location: "농부 마켓")
        timed("demo-may-115", 2026, 5, 17, 17, 0, 18, 30, title: "킥복싱", tint: butter, location: "헬스장")
        timed("demo-may-115b", 2026, 5, 17, 8, 30, 9, 15, title: "스트레칭", tint: mint, location: "집")
        // 5/18: sparse
        timed("demo-may-117", 2026, 5, 19, 9, 15, 10, 0, title: "여름 항공권 예약", tint: lilac)
        add(2026, 5, 20, CalendarEvent(id: "demo-may-003", eventIdentifier: nil, day: 20, title: "출시 마감 — 캘린더 앱", tint: lilac, allDay: true))
        timed("demo-may-003b", 2026, 5, 20, 10, 0, 10, 45, title: "출시 체크리스트 — 최종 확인", tint: coral, location: "Google Meet")
        timed("demo-may-118", 2026, 5, 21, 15, 0, 16, 0, title: "팀 회고", tint: sea, location: "Miro")
        timed("demo-may-118b", 2026, 5, 21, 9, 30, 10, 15, title: "회고 준비 — 메모", tint: butter)
        timed("demo-may-119", 2026, 5, 22, 20, 0, 22, 0, title: "스탠드업 코미디 라이브", tint: peach, location: "코미디 클럽")
        add(2026, 5, 23, CalendarEvent(id: "demo-may-120", eventIdentifier: nil, day: 23, title: "주말 캠핑", tint: sky, location: "가평", allDay: true))
        timed("demo-may-120b", 2026, 5, 23, 17, 0, 18, 30, title: "캠프파이어 + 바비큐", tint: peach, location: "가평")
        // 5/24: sparse
        timed("demo-may-122", 2026, 5, 25, 10, 0, 11, 30, title: "캠핑 장비 반납", tint: rose, location: "아웃도어 매장")
        timed("demo-may-123", 2026, 5, 26, 14, 30, 15, 45, title: "심리 상담", tint: mint)
        timed("demo-may-124", 2026, 5, 27, 8, 0, 9, 0, title: "전사 미팅 (아시아태평양)", tint: butter, location: "Google Meet")
        timed("demo-may-125", 2026, 5, 28, 18, 0, 19, 30, title: "데이트 나이트", tint: lilac, location: "오마카세")
        timed("demo-may-126", 2026, 5, 29, 12, 0, 13, 0, title: "점심 — 투자자 업데이트", tint: sea, location: "여의도 레스토랑")
        timed("demo-may-126b", 2026, 5, 29, 15, 30, 16, 30, title: "투자자 후속 메일", tint: lilac)
        // 5/30: sparse
        add(2026, 5, 31, CalendarEvent(id: "demo-may-127", eventIdentifier: nil, day: 31, title: "월간 사진 백업", tint: sky, allDay: true))
        timed("demo-may-127b", 2026, 5, 31, 18, 0, 18, 45, title: "iCloud 백업 확인", tint: mint)

        // MARK: 6월
        timed("demo-jun-101", 2026, 6, 1, 9, 30, 10, 30, title: "OKR 점검", tint: butter, location: "Notion")
        timed("demo-jun-101b", 2026, 6, 1, 14, 0, 15, 0, title: "OKR — 상사 승인", tint: sea, location: "Google Meet")
        timed("demo-jun-102", 2026, 6, 2, 17, 0, 18, 30, title: "아이 수영 교실", tint: sea, location: "수영장")
        timed("demo-jun-103", 2026, 6, 3, 12, 30, 13, 30, title: "점심 세미나 — 프라이버시", tint: lilac, location: "Google Meet")
        timed("demo-jun-103b", 2026, 6, 3, 16, 0, 16, 45, title: "개인정보 체크리스트", tint: coral, location: "드라이브")
        timed("demo-jun-104", 2026, 6, 4, 19, 30, 21, 0, title: "야외 영화 상영", tint: peach, location: "공원 야외 무대")
        timed("demo-jun-104b", 2026, 6, 4, 17, 0, 18, 30, title: "돗자리 + 간식 준비", tint: mint, location: "공원")
        add(2026, 6, 5, CalendarEvent(id: "demo-jun-105", eventIdentifier: nil, day: 5, title: "창고 정리", tint: coral, allDay: true))
        timed("demo-jun-105b", 2026, 6, 5, 10, 0, 12, 0, title: "대형 폐기물 배출", tint: butter, location: "재활용 센터")
        // 6/6: sparse
        timed("demo-jun-107", 2026, 6, 7, 15, 0, 16, 30, title: "가족 외식 — 삼겹살", tint: rose, location: "고깃집")
        timed("demo-jun-108", 2026, 6, 8, 10, 0, 11, 0, title: "온콜 인수인계", tint: sky, location: "PagerDuty")
        timed("demo-jun-109", 2026, 6, 9, 13, 0, 14, 30, title: "포트폴리오 점검", tint: butter, location: "증권사")
        timed("demo-jun-110", 2026, 6, 10, 18, 0, 19, 15, title: "클라이밍", tint: coral, location: "클라이밍짐")
        timed("demo-jun-111", 2026, 6, 11, 11, 30, 12, 45, title: "점심 — 새 PM 인사", tint: peach, location: "루프탑 카페")
        timed("demo-jun-111b", 2026, 6, 11, 9, 0, 9, 45, title: "사전 자료 — PRD v3", tint: lilac, location: "Notion")
        // 6/12: sparse
        add(2026, 6, 13, CalendarEvent(id: "demo-jun-113", eventIdentifier: nil, day: 13, title: "주말 여행 — 강릉", tint: sky, location: "바다 전망 펜션", allDay: true))
        timed("demo-jun-113b", 2026, 6, 13, 17, 0, 19, 0, title: "일몰 산책 — 해변", tint: coral, location: "경포해변")
        timed("demo-jun-114", 2026, 6, 14, 10, 0, 11, 30, title: "체크아웃 전 브런치", tint: mint, location: "바다 전망 펜션")
        timed("demo-jun-115", 2026, 6, 15, 16, 0, 17, 0, title: "세차", tint: sea, location: "세차장")
        timed("demo-jun-116", 2026, 6, 16, 9, 0, 10, 30, title: "접근성 점검", tint: rose, location: "테스트 랩")
        timed("demo-jun-117", 2026, 6, 17, 14, 0, 15, 30, title: "기부 물품 전달", tint: butter, location: "아름다운가게")
        timed("demo-jun-117b", 2026, 6, 17, 10, 0, 11, 0, title: "기부 물품 분류", tint: mint, location: "창고")
        // 6/18: sparse
        timed("demo-jun-119", 2026, 6, 19, 12, 0, 13, 0, title: "단오 — 수리취떡 만들기", tint: coral, location: "집")
        timed("demo-jun-119b", 2026, 6, 19, 15, 30, 16, 30, title: "단오 민속 행사 구경", tint: sea, location: "남산골한옥마을")
        timed("demo-jun-120", 2026, 6, 20, 8, 45, 10, 15, title: "베란다 가드닝", tint: peach, location: "베란다")
        add(2026, 6, 21, CalendarEvent(
            id: "demo-jun-001", eventIdentifier: nil, day: 21,
            startDate: date(2026, 6, 21, h: 18, min: 0),
            endDate: date(2026, 6, 21, h: 22, min: 30),
            title: "하지 — 바비큐 파티", tint: coral, location: "테라스", allDay: false
        ))
        timed("demo-jun-121", 2026, 6, 22, 9, 30, 10, 45, title: "벤더 보안 검토", tint: sea, location: "Google Meet")
        timed("demo-jun-122", 2026, 6, 23, 17, 30, 18, 45, title: "건강검진 — 연례", tint: mint, location: "건강검진센터")
        // 6/24: sparse
        timed("demo-jun-124", 2026, 6, 25, 19, 0, 20, 30, title: "입주자 대표 회의", tint: butter, location: "주민 커뮤니티")
        timed("demo-jun-124b", 2026, 6, 25, 12, 0, 13, 0, title: "회의 — 발언 메모 준비", tint: lilac)
        timed("demo-jun-125", 2026, 6, 26, 11, 0, 12, 30, title: "분기 계획 초안", tint: lilac, location: "Notion / FigJam")
        timed("demo-jun-126", 2026, 6, 27, 15, 0, 16, 30, title: "빈티지 마켓 구경", tint: peach, location: "동묘 벼룩시장")
        add(2026, 6, 28, CalendarEvent(id: "demo-jun-002", eventIdentifier: nil, day: 28, title: "결혼식 — 지은 & 민준", tint: rose, location: "더플라자 호텔", allDay: true))
        timed("demo-jun-002b", 2026, 6, 28, 8, 0, 9, 30, title: "결혼식 — 헤어 메이크업", tint: peach, location: "호텔")
        timed("demo-jun-127", 2026, 6, 29, 10, 0, 11, 0, title: "결혼식 다음날 브런치", tint: mint, location: "호텔 테라스")
        timed("demo-jun-127b", 2026, 6, 29, 14, 0, 15, 30, title: "감사 카드 쓰기", tint: butter, location: "호텔 로비")
        // 6/30: sparse

        sortedMap(&out)
        return out
    }
    // swiftlint:enable function_body_length
}
