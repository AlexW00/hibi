import Foundation
import SwiftUI
import Testing
@testable import Hibi

@Suite("EventRowEdges.radii(outer:)")
struct EventRowEdgesTests {

    private let outer: CGFloat = 12

    @Test func soloUsesAllOuter() {
        let r = EventRowEdges.solo.radii(outer: outer)
        #expect(r.topLeading == outer)
        #expect(r.topTrailing == outer)
        #expect(r.bottomLeading == outer)
        #expect(r.bottomTrailing == outer)
    }

    @Test func topOnlyHasOuterTopInnerBottom() {
        let edges = EventRowEdges(top: true, bottom: false)
        let r = edges.radii(outer: outer)
        #expect(r.topLeading == outer)
        #expect(r.topTrailing == outer)
        #expect(r.bottomLeading == EventRowEdges.innerRadius)
        #expect(r.bottomTrailing == EventRowEdges.innerRadius)
    }

    @Test func bottomOnlyHasInnerTopOuterBottom() {
        let edges = EventRowEdges(top: false, bottom: true)
        let r = edges.radii(outer: outer)
        #expect(r.topLeading == EventRowEdges.innerRadius)
        #expect(r.topTrailing == EventRowEdges.innerRadius)
        #expect(r.bottomLeading == outer)
        #expect(r.bottomTrailing == outer)
    }

    @Test func middleUsesAllInner() {
        let edges = EventRowEdges(top: false, bottom: false)
        let r = edges.radii(outer: outer)
        #expect(r.topLeading == EventRowEdges.innerRadius)
        #expect(r.topTrailing == EventRowEdges.innerRadius)
        #expect(r.bottomLeading == EventRowEdges.innerRadius)
        #expect(r.bottomTrailing == EventRowEdges.innerRadius)
    }

    @Test func widgetOuterRadiusPropagates() {
        let widgetOuter: CGFloat = 22
        let r = EventRowEdges.solo.radii(outer: widgetOuter)
        #expect(r.topLeading == widgetOuter)
        #expect(r.bottomTrailing == widgetOuter)
    }

    @Test func innerRadiusIsSmall() {
        #expect(EventRowEdges.innerRadius < 12)
        #expect(EventRowEdges.innerRadius > 0)
    }
}
