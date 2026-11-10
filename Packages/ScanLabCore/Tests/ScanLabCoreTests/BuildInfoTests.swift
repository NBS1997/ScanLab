import Foundation
import Testing

@testable import ScanLabCore

@Suite("Build info")
struct BuildInfoTests {
    let built = Date(timeIntervalSince1970: 1_794_268_800)  // 2026-11-10T00:00:00Z
    let day: TimeInterval = 86_400

    @Test("expiry is exactly 90 days after the build date")
    func expiryDate() {
        let info = BuildInfo(version: "0.1.0", build: "1", buildDate: built)
        #expect(info.expiryDate == built.addingTimeInterval(90 * day))
    }

    @Test("days left counts whole days and rounds down")
    func daysLeft() {
        let info = BuildInfo(version: "0.1.0", build: "1", buildDate: built)
        #expect(info.daysUntilExpiry(now: built) == 90)
        #expect(info.daysUntilExpiry(now: built.addingTimeInterval(29.5 * day)) == 60)
        #expect(info.expiryDescription(now: built.addingTimeInterval(29.5 * day)) == "in 60 days")
    }

    @Test("the last day, the final day and after expiry are described plainly")
    func endOfLife() {
        let info = BuildInfo(version: "0.1.0", build: "1", buildDate: built)
        #expect(info.expiryDescription(now: built.addingTimeInterval(88.5 * day)) == "in 1 day")
        #expect(info.expiryDescription(now: built.addingTimeInterval(89.5 * day)) == "today")
        #expect(info.expiryDescription(now: built.addingTimeInterval(90 * day)) == "expired")
        #expect(info.daysUntilExpiry(now: built.addingTimeInterval(120 * day)) == 0)
    }

    @Test("a missing build date gives no expiry rather than a wrong one")
    func missingBuildDate() {
        let info = BuildInfo(version: "0.1.0", build: "1", buildDate: nil)
        #expect(info.expiryDate == nil)
        #expect(info.daysUntilExpiry(now: built) == nil)
        #expect(info.expiryDescription(now: built) == "unknown (no build date)")
    }

    @Test("values are read from an Info.plist dictionary")
    func fromInfoDictionary() {
        let info = BuildInfo(infoDictionary: [
            "CFBundleShortVersionString": "0.1.0",
            "CFBundleVersion": "27",
            "SLBuildDate": "2026-11-10T00:00:00Z",
        ])
        #expect(info.versionDescription == "0.1.0 (27)")
        #expect(info.buildDate == built)
    }

    @Test("missing or malformed Info.plist values become unknown, not a crash")
    func fromEmptyInfoDictionary() {
        let info = BuildInfo(infoDictionary: ["SLBuildDate": "not a date"])
        #expect(info.versionDescription == "unknown (unknown)")
        #expect(info.buildDate == nil)
        #expect(BuildInfo.parseBuildDate("") == nil)
        #expect(BuildInfo.parseBuildDate(nil) == nil)
    }
}
