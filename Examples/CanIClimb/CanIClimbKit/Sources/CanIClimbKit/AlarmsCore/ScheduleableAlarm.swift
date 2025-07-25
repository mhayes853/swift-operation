import Foundation
import Tagged

public typealias ScheduleableAlarm = ScheduleableAlarmRecord

extension ScheduleableAlarm {
  public typealias ID = Tagged<ScheduleableAlarm, UUID>
}
