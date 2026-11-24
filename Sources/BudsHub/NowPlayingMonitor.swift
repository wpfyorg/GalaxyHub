import Foundation
import BudsKit

/// Polls the system now-playing state through MediaRemote and asks the buds to
/// take Mac audio when playback starts. Fails silently when the private symbol
/// is unavailable; the manual "Use this Mac" button still works.
@MainActor
final class NowPlayingMonitor {
    static let shared = NowPlayingMonitor()

    private typealias IsPlayingFunction = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void
    private var timer: Timer?
    private var function: IsPlayingFunction?
    private var wasPlaying = false
    private var inFlight = false
    private weak var controller: BudsController?
    private var handle: UnsafeMutableRawPointer?

    func start(controller: BudsController) {
        self.controller = controller
        guard function != nil || load() else { return }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        poll()
    }

    private func load() -> Bool {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW) else {
            return false
        }
        self.handle = handle
        guard let symbol = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying") else {
            return false
        }
        function = unsafeBitCast(symbol, to: IsPlayingFunction.self)
        return function != nil
    }

    private func poll() {
        guard let function, !inFlight else { return }
        inFlight = true
        function(DispatchQueue.main) { [weak self] playing in
            Task { @MainActor in
                guard let self else { return }
                self.inFlight = false
                let started = playing && !self.wasPlaying
                self.wasPlaying = playing
                guard started, let controller = self.controller,
                      controller.autoClaimAudio, controller.link == .connected else { return }
                controller.claimMacAudio()
            }
        }
    }

    deinit {
        timer?.invalidate()
        if let handle { dlclose(handle) }
    }
}
