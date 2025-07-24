import Foundation
import GRDB

extension DatabaseFunction {
  public static let localizedStandardContains = DatabaseFunction(
    "localizedStandardContains",
    argumentCount: 2,
    pure: true
  ) { args in
    let args = args.compactMap(String.fromDatabaseValue(_:))
    guard args.count == 2 else { return false }
    return args[0].localizedStandardContains(args[1])
  }
}
