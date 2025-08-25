import Foundation

public let disclaimer: LocalizedStringResource = """
  CanIClimb is a demonstration application intended solely to illustrate the integration of \
  Swift Operation within a moderately complex project that incorporates personalized data, \
  networking, offline functionality, large language models (Foundation Models), and various \
  Apple frameworks.

  This application simulates network activity using a lightweight protocol wrapper over \
  `URLSession` (see `HTTPTransport.swift`). No user data is transmitted to any external or live \
  server (see `DummyBackend.swift`).

  Any training or fitness-related guidance presented within this application is for illustrative \
  purposes only and has not been reviewed or approved by a licensed medical professional. \
  Users are advised to consult with a qualified healthcare or fitness professional before \
  acting on any such information.
  """
