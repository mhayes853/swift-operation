import Foundation
import SQLiteData

@DatabaseFunction
public func localizedStandardContains(s1: String, s2: String) -> Bool {
  s1.localizedStandardContains(s2)
}
