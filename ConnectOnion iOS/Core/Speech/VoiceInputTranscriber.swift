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

    @ObservationIgnored private let recognizer: SFSpeechRecognizer?
    @ObservationIgnored private let audioEngine = AVAudioEngine()
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
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
        state = .requestingPermission

        Task {
            do {
                try await requestPermissions()
                try beginRecognition()
            } catch {
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
    }

    private func requestPermissions() async throws {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        guard speechStatus == .authorized else {
            throw VoiceInputError.speechPermissionDenied
        }

        let microphoneGranted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }

        guard microphoneGranted else {
            throw VoiceInputError.microphonePermissionDenied
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

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.channelCount > 0 else {
            throw VoiceInputError.audioInputUnavailable
        }
        inputNode.removeTap(onBus: 0)
        try inputNode.__installTap(onBus: 0, bufferSize: 1024, format: format, error: ()) { [weak recognitionRequest] buffer, _ in
            recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        startedAt = .now
        state = .recording
        startTimer()

        task = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }

                if let result {
                    transcript = result.bestTranscription.formattedString
                    if result.isFinal {
                        finishRecognition()
                    }
                }

                if let error {
                    if !transcript.isEmpty {
                        finishRecognition()
                    } else {
                        fail(with: userFacingMessage(for: error))
                    }
                }
            }
        }
    }

    private func stopAudioCapture() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
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
        request = nil
        task = nil
    }

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self, let startedAt else { return }
                duration = Date.now.timeIntervalSince(startedAt)
            }
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
