extension ScheduleableAlarm {
  public init(record: ScheduleableAlarmRecord) {
    self.init(id: record.id, title: record.title, date: record.date)
  }
}

extension ScheduleableAlarmRecord {
  public init(alarm: ScheduleableAlarm, status: Status = .pending) {
    self.init(id: alarm.id, title: alarm.title, date: alarm.date, status: status)
  }
}
