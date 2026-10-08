import Foundation
import Combine
import Network

struct NetworkStatus: Equatable {
    enum Interface: String {
        case wifi
        case cellular
        case wiredEthernet
        case loopback
        case other
        case none
    }

    enum BandwidthCategory {
        case high
        case constrained
        case offline
    }

    var interface: Interface
    var isConnected: Bool
    var isExpensive: Bool
    var isConstrained: Bool

    init(
        interface: Interface = .none,
        isConnected: Bool = false,
        isExpensive: Bool = false,
        isConstrained: Bool = false
    ) {
        self.interface = interface
        self.isConnected = isConnected
        self.isExpensive = isExpensive
        self.isConstrained = isConstrained
    }

    init(path: NWPath) {
        self.isConnected = path.status == .satisfied
        self.isExpensive = path.isExpensive
        self.isConstrained = path.isConstrained

        if path.usesInterfaceType(.wifi) {
            self.interface = .wifi
        } else if path.usesInterfaceType(.wiredEthernet) {
            self.interface = .wiredEthernet
        } else if path.usesInterfaceType(.cellular) {
            self.interface = .cellular
        } else if path.usesInterfaceType(.loopback) {
            self.interface = .loopback
        } else if path.status == .satisfied {
            self.interface = .other
        } else {
            self.interface = .none
        }
    }

    var bandwidth: BandwidthCategory {
        guard isConnected else { return .offline }

        switch interface {
        case .wifi, .wiredEthernet:
            if isConstrained || isExpensive {
                return .constrained
            }
            return .high
        case .cellular:
            return .constrained
        case .loopback, .other:
            return isConstrained ? .constrained : .high
        case .none:
            return .offline
        }
    }
}

protocol NetworkStatusProviding {
    var currentStatus: NetworkStatus { get }
}

@MainActor
final class NetworkStatusService: ObservableObject, NetworkStatusProviding {
    @Published private(set) var status: NetworkStatus

    private let monitor: NWPathMonitor
    private let queue: DispatchQueue

    init(
        monitor: NWPathMonitor = NWPathMonitor(),
        queue: DispatchQueue = DispatchQueue(label: "com.financeapp.network.monitor")
    ) {
        self.monitor = monitor
        self.queue = queue
        self.status = NetworkStatus()

        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.status = NetworkStatus(path: path)
            }
        }

        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    var currentStatus: NetworkStatus {
        status
    }
}
