import Combine
import Network

enum NetworkStatus: Equatable, Sendable {
    case checking
    case online
    case offline
}

@MainActor
final class NetworkMonitor: ObservableObject {
    @Published private(set) var status: NetworkStatus = .checking

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "petalog.network.monitor")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let newStatus: NetworkStatus = path.status == .satisfied ? .online : .offline
            Task { @MainActor [weak self] in
                self?.status = newStatus
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
