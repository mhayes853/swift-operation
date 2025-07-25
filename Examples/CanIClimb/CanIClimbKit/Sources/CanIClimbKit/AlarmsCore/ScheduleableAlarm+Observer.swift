import GRDB

extension ScheduleableAlarm {
  public final actor Observer {
    private let database: any DatabaseWriter
    private let store: any Store
    private var task: Task<Void, Never>?

    public init(database: any DatabaseWriter, store: any Store) {
      self.database = database
      self.store = store
    }

    isolated deinit {
      self.endObserving()
    }
  }
}

extension ScheduleableAlarm.Observer {
  public func beginObserving() {

  }

  public func endObserving() {
    self.task?.cancel()
  }
}
