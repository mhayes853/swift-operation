import Foundation
import SharingGRDB
import StructuredQueries

// MARK: - SingleRowTable

public protocol SingleRowTable: PrimaryKeyedTable<UUID> where QueryOutput == Self {
  init()
}

extension SingleRowTable {
  public static func find(in db: Database) -> Self {
    let query = try? Self.find(UUID.null).fetchOne(db)
    return query ?? Self()
  }
}

extension SingleRowTable {
  public func save(in db: Database) throws {
    try Self.upsert { Self.Draft(self) }.execute(db)
  }
}

// MARK: - SingleRowTableRequest

public struct SingleRowTableRequest<Table: SingleRowTable>: FetchKeyRequest {
  public func fetch(_ db: Database) throws -> Table {
    Table.find(in: db)
  }
}

extension FetchKeyRequest {
  public static func singleRow<Table: SingleRowTable>(
    _ table: Table.Type
  ) -> SingleRowTableRequest<Table> where Self == SingleRowTableRequest<Table> {
    SingleRowTableRequest()
  }
}
