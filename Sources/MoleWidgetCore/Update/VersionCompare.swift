/// Pure semver-ish comparison for release tags ("0.4.0", "v0.4.0").
public enum VersionCompare {
    /// True when `candidate` is strictly newer than `current`.
    /// Components are compared numerically; missing components count as 0.
    /// Unparseable candidates are never "newer".
    public static func isNewer(_ candidate: String, than current: String) -> Bool {
        guard let lhs = components(of: candidate), let rhs = components(of: current) else {
            return false
        }
        let count = max(lhs.count, rhs.count)
        for i in 0..<count {
            let l = i < lhs.count ? lhs[i] : 0
            let r = i < rhs.count ? rhs[i] : 0
            if l != r { return l > r }
        }
        return false
    }

    private static func components(of version: String) -> [Int]? {
        var v = version.trimmingCharacters(in: .whitespaces)
        if v.hasPrefix("v") || v.hasPrefix("V") { v.removeFirst() }
        guard !v.isEmpty else { return nil }
        var result: [Int] = []
        for part in v.split(separator: ".") {
            guard let number = Int(part) else { return nil }
            result.append(number)
        }
        return result.isEmpty ? nil : result
    }
}
