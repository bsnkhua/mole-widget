import Foundation
import Testing
@testable import MoleWidgetCore

@Suite struct VersionCompareTests {
    @Test func newerVersionsDetected() {
        #expect(VersionCompare.isNewer("0.4.0", than: "0.3.0"))
        #expect(VersionCompare.isNewer("1.0.0", than: "0.9.9"))
        #expect(VersionCompare.isNewer("0.3.1", than: "0.3.0"))
        // numeric, not lexicographic
        #expect(VersionCompare.isNewer("0.10.0", than: "0.9.9"))
    }

    @Test func olderOrEqualVersionsRejected() {
        #expect(!VersionCompare.isNewer("0.3.0", than: "0.3.0"))
        #expect(!VersionCompare.isNewer("0.2.9", than: "0.3.0"))
        #expect(!VersionCompare.isNewer("0.3.0", than: "0.10.0"))
    }

    @Test func vPrefixAccepted() {
        #expect(VersionCompare.isNewer("v0.4.0", than: "0.3.0"))
        #expect(VersionCompare.isNewer("v0.4.0", than: "v0.3.0"))
    }

    @Test func missingComponentsAreZero() {
        #expect(VersionCompare.isNewer("0.4", than: "0.3.9"))
        #expect(!VersionCompare.isNewer("0.3", than: "0.3.0"))
    }

    @Test func garbageRejected() {
        #expect(!VersionCompare.isNewer("", than: "0.3.0"))
        #expect(!VersionCompare.isNewer("not-a-version", than: "0.3.0"))
    }
}

@Suite struct UpdateCheckerTests {
    @Test func parsesTagFromReleaseJSON() {
        let json = #"{"tag_name": "v0.4.0", "name": "v0.4.0", "draft": false}"#
        #expect(UpdateChecker.parseTag(fromJSON: Data(json.utf8)) == "v0.4.0")
    }

    @Test func returnsNilForMalformedJSON() {
        #expect(UpdateChecker.parseTag(fromJSON: Data("not json".utf8)) == nil)
        #expect(UpdateChecker.parseTag(fromJSON: Data("{}".utf8)) == nil)
    }
}
