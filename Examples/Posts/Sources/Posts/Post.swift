struct Post: Hashable, Identifiable, Sendable, Codable {
  let id: Int
  var userId: Int
  var title: String
  var body: String
}
