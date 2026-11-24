import Foundation
import BudsKit

/// Polls the system now-playing state and asks the buds to take Mac audio when
/// playback starts. Direct MediaRemote calls are blocked for third-party apps on
/// macOS 15.4+, so this uses the Apple-signed `osascript` helper. It runs only
/// while the auto-claim setting is on.
@MainActor
final class NowPlayingMonitor {
    static let shared = NowPlayingMonitor()

    private var timer: Timer?
    private var wasPlaying = false
    private var inFlight = false
    private weak var controller: BudsController?

    func start(controller: BudsController) {
        self.controller = controller
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
    }

    private func poll() {
        guard let controller, controller.autoClaimAudio, !inFlight else { return }
        inFlight = true
        DispatchQueue.global(qos: .utility).async {
            let playing = Self.nowPlaying()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.inFlight = false
                let started = playing && !self.wasPlaying
                guard started, self.controller?.autoClaimAudio == true else {
                    self.wasPlaying = playing
                    return
                }
                guard self.controller?.link == .connected else {
                    // Keep wasPlaying false so the claim is retried once the
                    // link is up, instead of missing this playback session.
                    self.wasPlaying = false
                    return
                }
                self.wasPlaying = self.controller?.claimMacAudio() == true
            }
        }
    }

    private static func nowPlaying() -> Bool {
        let script = #"""
        ObjC.import('Foundation');
        const bundle = $.NSBundle.bundleWithPath('/System/Library/PrivateFrameworks/MediaRemote.framework/');
        bundle.load;
        const R = $.NSClassFromString('MRNowPlayingRequest');
        const item = R.localNowPlayingItem;
        if (!item || item.isNil()) {
            JSON.stringify({ exists: false, playing: false });
        } else {
            const info = item.nowPlayingInfo;
            const get = k => { const v = info.valueForKey(k); return v && !v.isNil() ? ObjC.unwrap(v) : null; };
            const rate = Number(get('kMRMediaRemoteNowPlayingInfoPlaybackRate') ?? 0);
            JSON.stringify({ exists: true, playing: rate > 0, rate: rate });
        }
        """#
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-l", "JavaScript", "-e", script]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return false }
            let data = output.fileHandleForReading.readDataToEndOfFile()
            guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let playing = object["playing"] as? Bool else { return false }
            return playing
        } catch {
            return false
        }
    }

    deinit {
        timer?.invalidate()
    }
}
