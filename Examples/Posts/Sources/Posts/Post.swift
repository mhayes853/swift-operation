package struct Post: Hashable, Identifiable, Sendable, Codable {
  package let id: Int
  package var userId: Int
  package var title: String
  package var body: String

  package init(id: Int, userId: Int, title: String, body: String) {
    self.id = id
    self.userId = userId
    self.title = title
    self.body = body
  }
}
