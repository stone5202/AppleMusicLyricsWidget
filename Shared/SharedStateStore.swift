import Foundation

actor SharedStateStore {
    static let shared = SharedStateStore()

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        defaults = UserDefaults(suiteName: AppConstants.appGroup) ?? .standard
    }

    func save(_ state: SharedLyricsState) throws {
        let data = try encoder.encode(state)
        defaults.set(data, forKey: AppConstants.sharedStateKey)
    }

    func load() -> SharedLyricsState {
        guard let data = defaults.data(forKey: AppConstants.sharedStateKey),
              let state = try? decoder.decode(SharedLyricsState.self, from: data) else {
            return .empty
        }
        return state
    }
}
