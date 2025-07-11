import Dependencies
import Foundation
import SharingQuery

// MARK: - Edit

extension User {
  public struct Edit: Hashable, Sendable, Codable {
    public var name: PersonNameComponents
    public var subtitle: String

    public init(name: PersonNameComponents, subtitle: String) {
      self.name = name
      self.subtitle = subtitle
    }
  }
}

// MARK: - Editor

extension User {
  public protocol Editor: Sendable {
    func editUser(with edit: Edit) async throws -> User
  }

  public enum EditorKey: DependencyKey {
    public static let liveValue: any User.Editor = CanIClimbAPI.shared
  }
}

extension CanIClimbAPI: User.Editor {}

extension User {
  @MainActor
  public final class MockEditor: Editor {
    public private(set) var edits = [Edit]()
    public var result: Result<User, any Error>

    public init(result: Result<User, any Error>) {
      self.result = result
    }

    public func editUser(with edit: User.Edit) async throws -> User {
      self.edits.append(edit)
      return try self.result.get()
    }
  }
}

// MARK: - Mutation

extension User {
  public static let editMutation = EditMutation()

  public struct EditMutation: MutationRequest, Hashable {
    public struct Arguments: Sendable {
      let edit: User.Edit

      public init(edit: User.Edit) {
        self.edit = edit
      }
    }

    public func mutate(
      with arguments: Arguments,
      in context: QueryContext,
      with continuation: QueryContinuation<User>
    ) async throws -> User {
      @Dependency(\.defaultQueryClient) var client
      @Dependency(User.EditorKey.self) var editor
      @Dependency(CurrentUser.self) var currentUser

      let user = try await currentUser.edit(with: arguments.edit, using: editor)
      client.store(for: User.currentQuery).currentValue = user
      return user
    }
  }
}
