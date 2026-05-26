import Foundation
import SwiftUI

@MainActor
@Observable
final class AppSettings {
    @ObservationIgnored @AppStorage("dailyStandGoalMinutes") private var _dailyStandGoalMinutes: Int = 120
    @ObservationIgnored @AppStorage("remindAfterSittingMinutes") private var _remindAfterSittingMinutes: Int = 45
    @ObservationIgnored @AppStorage("notificationsEnabled") private var _notificationsEnabled: Bool = true
    @ObservationIgnored @AppStorage("sitThresholdMm") private var _sitThresholdMm: Int = 633
    @ObservationIgnored @AppStorage("standThresholdMm") private var _standThresholdMm: Int = 937

    var dailyStandGoalMinutes: Int {
        get { access(keyPath: \.dailyStandGoalMinutes); return _dailyStandGoalMinutes }
        set { withMutation(keyPath: \.dailyStandGoalMinutes) { _dailyStandGoalMinutes = newValue } }
    }
    var dailyStandGoalSeconds: TimeInterval { TimeInterval(dailyStandGoalMinutes * 60) }

    var remindAfterSittingMinutes: Int {
        get { access(keyPath: \.remindAfterSittingMinutes); return _remindAfterSittingMinutes }
        set { withMutation(keyPath: \.remindAfterSittingMinutes) { _remindAfterSittingMinutes = newValue } }
    }

    var notificationsEnabled: Bool {
        get { access(keyPath: \.notificationsEnabled); return _notificationsEnabled }
        set { withMutation(keyPath: \.notificationsEnabled) { _notificationsEnabled = newValue } }
    }

    var sitThresholdMm: Int {
        get { access(keyPath: \.sitThresholdMm); return _sitThresholdMm }
        set { withMutation(keyPath: \.sitThresholdMm) { _sitThresholdMm = newValue } }
    }

    var standThresholdMm: Int {
        get { access(keyPath: \.standThresholdMm); return _standThresholdMm }
        set { withMutation(keyPath: \.standThresholdMm) { _standThresholdMm = newValue } }
    }
}
