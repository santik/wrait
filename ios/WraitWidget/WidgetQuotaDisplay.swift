import Foundation

/// Pure logic for the home-screen widget's daily recording quota (spec 055
/// plan D-6). Mirrors the Android `WidgetQuotaDisplay`. Kept free of WidgetKit
/// so it can be unit-tested (XCTest).
enum WidgetQuotaDisplay {
    struct Quota: Equatable {
        let used: Int
        let limit: Int
    }

    /// Applies the optimistic daily reset: once `nowMs` has reached the cached
    /// `resetAtMs` boundary, the day is shown as fresh (0 used) until the app
    /// next syncs real values from the backend.
    static func resolve(used: Int, limit: Int, resetAtMs: Double, nowMs: Double) -> Quota {
        let safeLimit = max(0, limit)
        if nowMs >= resetAtMs {
            return Quota(used: 0, limit: safeLimit)
        }
        return Quota(used: min(max(0, used), safeLimit), limit: safeLimit)
    }

    /// Renders the quota as "used / total".
    static func format(_ quota: Quota) -> String {
        "\(quota.used) / \(quota.limit)"
    }
}
