import Foundation

/// Canonical GitHub links used by the menu bar. Update detection itself is
/// handled in-app by Sparkle (see SUFeedURL in Info.plist), not here.
public enum UpdateChecker {
    public static let releasesPageURL = URL(string: "https://github.com/TadelUnso/mole-widget/releases")!
    public static let repoPageURL = URL(string: "https://github.com/TadelUnso/mole-widget")!
    public static let issuesPageURL = URL(string: "https://github.com/TadelUnso/mole-widget/issues")!
}
