import Foundation

/// Checks GitHub for a newer release. One unauthenticated API call;
/// any failure (offline, rate limit) quietly returns nil.
public struct UpdateChecker {
    public static let releasesPageURL = URL(string: "https://github.com/bsnkhua/mole-widget/releases")!

    private static let latestReleaseAPI =
        URL(string: "https://api.github.com/repos/bsnkhua/mole-widget/releases/latest")!

    public init() {}

    /// Latest release tag (e.g. "v0.4.0") or nil on any failure.
    public func latestReleaseTag() async -> String? {
        var request = URLRequest(url: Self.latestReleaseAPI)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        return Self.parseTag(fromJSON: data)
    }

    /// Extracts "tag_name" from the GitHub release JSON. Pure and testable.
    static func parseTag(fromJSON data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = object["tag_name"] as? String,
              !tag.isEmpty
        else { return nil }
        return tag
    }
}
