import Dependencies
import Foundation
import IdentifiedCollections
import OrderedCollections

// MARK: - UserData

extension DummyBackend {
  struct UserData: Hashable, Sendable, Codable {
    var activeUserId: User.ID?
    var profiles = IdentifiedArrayOf<User>()
    var plannedClimbs = IdentifiedArrayOf<CanIClimbAPI.PlannedClimbResponse>()
  }
}

extension DummyBackend.UserData {
  init(scenario: DummyBackend.Scenario) {
    self.init(
      activeUserId: scenario.currentUserId,
      profiles: IdentifiedArray(uniqueElements: scenario.users),
      plannedClimbs: IdentifiedArray(uniqueElements: scenario.plannedClimbs)
    )
  }
}

// MARK: - Storage

extension DummyBackend.UserData {
  final actor Storage {
    private var data: DummyBackend.UserData?
    private let persistenceURL: URL?

    init() {
      self.persistenceURL = .dummyBackendUserData
    }

    init(data: DummyBackend.UserData) {
      self.data = data
      self.persistenceURL = nil
    }

    var currentUser: User? {
      try? self.access { data in
        guard let id = data.activeUserId else { return nil }
        return data.profiles[id: id]
      }
    }

    var plannedMountainIds: Set<Mountain.ID> {
      let ids = try? self.access { data in
        Set(data.plannedClimbs.map(\.mountainId))
      }
      return ids ?? []
    }

    func editCurrentUser(with edit: User.Edit) throws -> User? {
      try self.access { data in
        guard let id = data.activeUserId else { return nil }
        data.profiles[id: id]?.name = edit.name
        data.profiles[id: id]?.subtitle = edit.subtitle
        return data.profiles[id: id]
      }
    }

    func signInUser(with credentials: User.SignInCredentials) throws {
      try self.access { data in
        data.activeUserId = credentials.userId
        if data.profiles[id: credentials.userId] == nil {
          data.profiles.append(User(id: credentials.userId, name: credentials.name))
        }
      }
    }

    func signOutCurrentUser() throws {
      try self.access { $0.activeUserId = nil }
    }

    func deleteCurrentUser() throws {
      try self.access { data in
        guard let id = data.activeUserId else { return }
        data.activeUserId = nil
        data.profiles.remove(id: id)
      }
    }

    func plannedClimbs(
      for id: Mountain.ID
    ) throws -> IdentifiedArrayOf<CanIClimbAPI.PlannedClimbResponse> {
      try self.access { data in
        IdentifiedArray(
          uniqueElements: data.plannedClimbs.filter { $0.mountainId == id }
            .sorted { $0.targetDate > $1.targetDate }
        )
      }
    }

    func planClimb(
      with request: CanIClimbAPI.PlanClimbRequest
    ) throws -> CanIClimbAPI.PlannedClimbResponse {
      try self.access { data in
        let plan = CanIClimbAPI.PlannedClimbResponse(
          id: Mountain.PlannedClimb.ID(),
          mountainId: request.mountainId,
          targetDate: request.targetDate,
          achievedDate: nil
        )
        data.plannedClimbs.append(plan)
        return plan
      }
    }

    func unplanClimbs(with ids: OrderedSet<Mountain.PlannedClimb.ID>) throws {
      try self.access { $0.plannedClimbs.removeAll { ids.contains($0.id) } }
    }

    func achieveClimb(
      with id: Mountain.PlannedClimb.ID
    ) throws -> CanIClimbAPI.PlannedClimbResponse? {
      @Dependency(\.date.now) var now
      return try self.access {
        $0.plannedClimbs[id: id]?.achievedDate = now
        return $0.plannedClimbs[id: id]
      }
    }

    func unachieveClimb(
      with id: Mountain.PlannedClimb.ID
    ) throws -> CanIClimbAPI.PlannedClimbResponse? {
      try self.access {
        $0.plannedClimbs[id: id]?.achievedDate = nil
        return $0.plannedClimbs[id: id]
      }
    }

    private func access<T>(_ fn: (inout DummyBackend.UserData) throws -> T) throws -> T {
      if self.data == nil {
        let savedData = self.persistenceURL.flatMap { url in
          try? JSONDecoder()
            .decode(DummyBackend.UserData.self, from: Data(contentsOf: url))
        }
        self.data = savedData ?? DummyBackend.UserData()
      }
      let value = try fn(&self.data!)
      if let persistenceURL = self.persistenceURL {
        try JSONEncoder().encode(self.data!).write(to: persistenceURL)
      }
      return value
    }
  }
}

// MARK: - URL

extension URL {
  fileprivate static let dummyBackendUserData = Self.documentsDirectory
    .appending(path: "dummy-backend-user-data.json")
}
