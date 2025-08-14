import Dependencies
import Foundation
import IssueReporting
import SharingGRDB
import StructuredQueries
import SwiftUI

// MARK: - SingleRowTable

public protocol SingleRowTable: PrimaryKeyedTable<UUID> where QueryOutput == Self {
  init()
}

extension SingleRowTable {
  public static func find(in db: Database) -> Self {
    let query = try? Self.find(UUID.nil).fetchOne(db)
    return query ?? Self()
  }

  public func save(in db: Database) throws {
    try Self.upsert { Self.Draft(self) }.execute(db)
  }

  public static func update<T>(
    in db: Database,
    _ update: @Sendable (inout Self) throws -> T
  ) throws -> T {
    var table = Self.find(in: db)
    let value = try update(&table)
    try table.save(in: db)
    return value
  }
}

// MARK: - SingleRow

@propertyWrapper
public struct SingleRow<Table: SingleRowTable & Sendable> {
  @Fetch(SingleRowTableRequest<Table>()) private var value = Table()

  @Dependency(\.defaultDatabase) private var database

  public var wrappedValue: Table {
    get { self.value }
    set {
      withErrorReporting {
        try self.database.write { db in
          try Table.update(in: db) { $0 = newValue }
        }
      }
    }
  }

  public init(_ type: Table.Type) {
  }
}

extension SingleRow: DynamicProperty {
  public func update() {
    self.$value.update()
  }
}

// MARK: - SingleRowTableRequest

private struct SingleRowTableRequest<Table: SingleRowTable>: FetchKeyRequest {
  func fetch(_ db: Database) throws -> Table {
    Table.find(in: db)
  }
}
