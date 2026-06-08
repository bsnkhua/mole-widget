import Foundation
import Testing
@testable import MoleWidgetCore

@Suite struct UpdateCheckerTests {
    @Test func repoPageURL() {
        #expect(UpdateChecker.repoPageURL.absoluteString == "https://github.com/bsnkhua/mole-widget")
    }

    @Test func issuesPageURL() {
        #expect(UpdateChecker.issuesPageURL.absoluteString == "https://github.com/bsnkhua/mole-widget/issues")
    }

    @Test func releasesPageURL() {
        #expect(UpdateChecker.releasesPageURL.absoluteString == "https://github.com/bsnkhua/mole-widget/releases")
    }
}
