extension Sequence {
  func removeFirstDuplicates<Value: Hashable>(by path: KeyPath<Element, Value>) -> [Element] {
    var seen = Set<Value>()
    return self.reversed().filter { seen.insert($0[keyPath: path]).inserted }.reversed()
  }
}
