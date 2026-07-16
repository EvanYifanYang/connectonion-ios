import AVFoundation
import Foundation
import Observation
import Speech

@MainActor
@Observable
final class VoiceInputTranscriber {
    enum RecordingState: Equatable {
        case idle
        case requestingPermission
        case recording
        case transcribing
    }

    var state: RecordingState = .idle
    var transcript = ""
    var errorMessage: String?
    var duration: TimeInterval = 0
    /// Rolling window of recent normalized mic levels (0...1), newest last — drives the live waveform.
    var levels: [CGFloat] = []

    @ObservationIgnored private let maxLevelSamples = 44

    @ObservationIgnored private let recognizer: SFSpeechRecognizer?
    @ObservationIgnored private let audioEngine = AVAudioEngine()
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    @ObservationIgnored private var audioTapBridge: AudioTapBridge?
    @ObservationIgnored private var timerTask: Task<Void, Never>?
    @ObservationIgnored private var fallbackFinishTask: Task<Void, Never>?
    @ObservationIgnored private var startedAt: Date?

    init(locale: Locale = .autoupdatingCurrent) {
        recognizer = SFSpeechRecognizer(locale: locale)
    }

    var isActive: Bool {
        state == .requestingPermission || state == .recording || state == .transcribing
    }

    func startRecording() {
        guard state == .idle else { return }
        errorMessage = nil
        transcript = ""
        duration = 0
        levels = []
        state = .requestingPermission

        Task {
            do {
                try await requestPermissions()
                guard state == .requestingPermission else { return } // cancelled while awaiting permission
                try beginRecognition()
            } catch {
                guard state == .requestingPermission else { return } // don't clobber state after a cancel
                fail(with: userFacingMessage(for: error))
            }
        }
    }

    func stopRecording() {
        guard state == .recording else { return }
        state = .transcribing
        stopAudioCapture()
        scheduleFallbackFinish()
    }

    func cancel() {
        task?.cancel()
        stopAudioCapture()
        cleanupRecognition()
        state = .idle
        transcript = ""
        errorMessage = nil
        levels = []
    }

    private func requestPermissions() async throws {
        let speechStatus = await Self.requestSpeechAuthorization()

        guard speechStatus == .authorized else {
            throw VoiceInputError.speechPermissionDenied
        }

        let microphoneGranted = await Self.requestMicrophonePermission()

        guard microphoneGranted else {
            throw VoiceInputError.microphonePermissionDenied
        }
    }

    nonisolated private static func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    nonisolated private static func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func beginRecognition() throws {
        guard let recognizer, recognizer.isAvailable else {
            throw VoiceInputError.speechUnavailable
        }

        task?.cancel()
        task = nil

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest.shouldReportPartialResults = true
        request = recognitionRequest
        let audioTapBridge = AudioTapBridge(request: recognitionRequest)
        self.audioTapBridge = audioTapBridge

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.channelCount > 0 else {
            throw VoiceInputError.audioInputUnavailable
        }
        inputNode.removeTap(onBus: 0)
        // Note: the throwing __installTap(onBus:bufferSize:format:error:block:) variant is iOS 27-only;
        // use the classic non-throwing installTap (iOS 8+) for the iOS 26 build.
        inputNode.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: format,
            block: Self.makeAudioTapHandler(bridge: audioTapBridge)
        )

        audioEngine.prepare()
        try audioEngine.start()
        startedAt = .now
        state = .recording
        startTimer()

        task = recognizer.recognitionTask(
            with: recognitionRequest,
            resultHandler: Self.makeRecognitionHandler(owner: self)
        )
    }

    private func stopAudioCapture() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioTapBridge?.endAudio()
        stopTimer()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func finishRecognition() {
        stopAudioCapture()
        cleanupRecognition()
        state = .idle
    }

    private func fail(with message: String) {
        stopAudioCapture()
        cleanupRecognition()
        errorMessage = message
        state = .idle
    }

    private func cleanupRecognition() {
        fallbackFinishTask?.cancel()
        fallbackFinishTask = nil
        timerTask?.cancel()
        timerTask = nil
        startedAt = nil
        audioTapBridge = nil
        request = nil
        task = nil
    }

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                guard let self, let startedAt else { return }
                duration = Date.now.timeIntervalSince(startedAt)
                appendLevelSample(CGFloat(audioTapBridge?.level ?? 0))
            }
        }
    }

    private func appendLevelSample(_ level: CGFloat) {
        levels.append(level)
        if levels.count > maxLevelSamples {
            levels.removeFirst(levels.count - maxLevelSamples)
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
        startedAt = nil
    }

    private func scheduleFallbackFinish() {
        fallbackFinishTask?.cancel()
        fallbackFinishTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(900))
            guard let self, state == .transcribing else { return }
            finishRecognition()
        }
    }

    private func userFacingMessage(for error: Error) -> String {
        if let error = error as? VoiceInputError {
            return error.localizedDescription
        }

        return "Could not transcribe audio. Try again in a quieter place."
    }

    private func handleRecognitionCallback(
        transcript newTranscript: String?,
        isFinal: Bool,
        errorMessage: String?
    ) {
        // Ignore stragglers that arrive after the session already ended (cancel / fail / fallback-finish
        // set state to .idle) — otherwise a late result re-injects discarded text or a late cancellation
        // error pops a spurious banner.
        guard state != .idle else { return }

        if let newTranscript {
            transcript = newTranscript
            if isFinal {
                finishRecognition()
            }
        }

        if let errorMessage {
            if !transcript.isEmpty {
                finishRecognition()
            } else {
                fail(with: errorMessage)
            }
        }
    }

    nonisolated private static func makeAudioTapHandler(
        bridge: AudioTapBridge
    ) -> @Sendable (AVAudioPCMBuffer, AVAudioTime) -> Void {
        { buffer, _ in
            bridge.append(buffer)
        }
    }

    nonisolated private static func makeRecognitionHandler(
        owner: VoiceInputTranscriber
    ) -> @Sendable (SFSpeechRecognitionResult?, Error?) -> Void {
        { [weak owner] result, error in
            let transcript = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let errorMessage = error.map(Self.userFacingMessage)
            Task { @MainActor [weak owner] in
                guard let owner else { return }
                owner.handleRecognitionCallback(
                    transcript: transcript,
                    isFinal: isFinal,
                    errorMessage: errorMessage
                )
            }
        }
    }

    nonisolated private static func userFacingMessage(for error: Error) -> String {
        if let error = error as? VoiceInputError {
            return error.localizedDescription
        }

        return "Could not transcribe audio. Try again in a quieter place."
    }
}

private final class AudioTapBridge: @unchecked Sendable {
    private let request: SFSpeechAudioBufferRecognitionRequest
    private let lock = NSLock()
    private var _level: Float = 0

    init(request: SFSpeechAudioBufferRecognitionRequest) {
        self.request = request
    }

    /// Latest normalized mic level (0...1), sampled by the transcriber's timer for the waveform.
    var level: Float {
        lock.lock(); defer { lock.unlock() }
        return _level
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        request.append(buffer)
        let level = Self.normalizedPower(of: buffer)
        lock.lock()
        _level = level
        lock.unlock()
    }

    func endAudio() {
        request.endAudio()
    }

    /// RMS of the buffer mapped from dBFS onto 0...1 so quiet ≈ 0 and normal speech ≈ 1.
    private static func normalizedPower(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }

        let samples = channelData[0]
        var sumOfSquares: Float = 0
        for index in 0..<frameLength {
            let sample = samples[index]
            sumOfSquares += sample * sample
        }

        let rms = sqrt(sumOfSquares / Float(frameLength))
        let decibels = 20 * log10(max(rms, 1e-7))
        let floorDecibels: Float = -50
        let clamped = max(floorDecibels, min(0, decibels))
        return (clamped - floorDecibels) / (0 - floorDecibels)
    }
}

private enum VoiceInputError: LocalizedError {
    case speechPermissionDenied
    case microphonePermissionDenied
    case speechUnavailable
    case audioInputUnavailable

    var errorDescription: String? {
        switch self {
        case .speechPermissionDenied:
            "Enable Speech Recognition in Settings to dictate messages."
        case .microphonePermissionDenied:
            "Enable Microphone access in Settings to dictate messages."
        case .speechUnavailable:
            "Speech recognition is not available right now."
        case .audioInputUnavailable:
            "Audio input is not available right now."
        }
    }
}
