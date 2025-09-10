import FoundationModels
import GRDB
import SQLiteData

public struct UserHumanityTool: Tool {
  @Generable
  public struct Arguments {}

  public let name = "User Humanity"
  public let description =
    "Provides basic health details (age, gender, height, weight) about the user."

  private let database: any DatabaseReader

  public init(database: any DatabaseReader) {
    self.database = database
  }

  public func call(arguments: Arguments) async throws -> UserHumanityGenerable {
    try await self.database.read { db in
      UserHumanityGenerable(record: UserHumanityRecord.find(in: db))
    }
  }
}
