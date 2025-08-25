# Can I Climb

This app demonstrates how Swift Operation can be used in a relatively modern and complex application involving integration with many Apple Frameworks (including Foundation Models), REST APIs, iCloud Sync, and offline persistence.

The app itself analyzes a user's fitness data to create a training program that helps them climb mountains. The user can also set certain mountains as their target climbing goal, and this data will be synced across their devices with iCloud. Additionally, the app loads mountain data from a REST API and displays it on a map, allowing users to explore and plan their climbing adventures. If a mountain is not found in the app, a user can submit a request to add it to the global database.

When viewing the details for the mountain, the user will see a generated training plan, alongside many of the mountain's climate conditions. The training plan is personalized based on data from the onboarding and HealthKit.
