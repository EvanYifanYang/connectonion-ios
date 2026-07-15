import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ChatInputBar: View {
    var placeholder: String
    var isRunning: Bool
    var acceptedInputs: AgentAcceptedInputs?
    var skills: [SkillInfo]
    var onSend: (String, [String], [FileAttachment]) -> Void
    var onStop: () -> Void

    @State private var text = ""
    @State private var imageAttachments: [ImageAttachmentDraft] = []
    @State private var fileAttachments: [FileAttachment] = []
    @State private var voiceInput = VoiceInputTranscriber()
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showingAttachmentOptions = false
    @State private var showingPhotoPicker = false
    @State private var showingFileImporter = false
    @State private var attachmentError: String?
    @State private var voiceSeedText = ""
    @State private var feedbackTrigger = 0
    @State private var errorFeedbackTrigger = 0
    @FocusState private var isFocused: Bool

    init(
        placeholder: String,
        isRunning: Bool,
        acceptedInputs: AgentAcceptedInputs? = nil,
        skills: [SkillInfo] = [],
        onSend: @escaping (String, [String], [FileAttachment]) -> Void,
        onStop: @escaping () -> Void
    ) {
        self.placeholder = placeholder
        self.isRunning = isRunning
        self.acceptedInputs = acceptedInputs
        self.skills = skills
        self.onSend = onSend
        self.onStop = onStop
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if hasAttachments {
                ComposerAttachmentPreviewStrip(
                    images: imageAttachments,
                    files: fileAttachments,
                    onRemoveImage: removeImage,
                    onRemoveFile: removeFile
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if let attachmentError {
                Label(attachmentError, systemImage: "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 8)
                    .accessibilityIdentifier(AccessibilityID.chatAttachmentError)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }

            if let voiceError = voiceInput.errorMessage {
                Label(voiceError, systemImage: "mic.slash.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 8)
                    .accessibilityIdentifier(AccessibilityID.chatVoiceError)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }

            if voiceInput.isActive {
                VoiceInputStatusPill(state: voiceInput.state, duration: voiceInput.duration, transcript: voiceInput.transcript)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if shouldShowSkillPalette {
                SkillCommandPalette(skills: filteredSkills, onSelect: selectSkill)
                    .transition(AppMotion.panelTransition)
            }

            HStack(alignment: .bottom, spacing: 10) {
                if allowsAttachments {
                    Button("Add attachment", systemImage: "plus", action: showAttachmentMenu)
                        .labelStyle(.iconOnly)
                        .frame(width: 40, height: 40)
                        .buttonStyle(.glass)
                        .disabled(remainingAttachmentSlots == 0 || voiceInput.isActive)
                        .accessibilityIdentifier(AccessibilityID.chatAttachmentButton)
                }

                TextField(placeholder, text: $text, axis: .vertical)
                    .lineLimit(1...6)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .submitLabel(.send)
                    .onSubmit(send)
                    .padding(.vertical, 12)
                    .disabled(voiceInput.isActive)
                    .accessibilityIdentifier(AccessibilityID.chatInput)

                if isRunning {
                    Button("Stop", systemImage: "stop.fill", action: stop)
                        .labelStyle(.iconOnly)
                        .frame(width: 44, height: 44)
                        .buttonStyle(.glass)
                        .accessibilityIdentifier(AccessibilityID.chatStopButton)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                } else {
                    Button(voiceButtonTitle, systemImage: voiceButtonSystemImage, action: toggleVoiceInput)
                        .labelStyle(.iconOnly)
                        .frame(width: 42, height: 42)
                        .buttonStyle(.glass)
                        .foregroundStyle(voiceInput.state == .recording ? .red : .primary)
                        .disabled(voiceInput.state == .requestingPermission || voiceInput.state == .transcribing)
                        .accessibilityIdentifier(AccessibilityID.chatVoiceButton)

                    Button("Send", systemImage: "arrow.up", action: send)
                        .labelStyle(.iconOnly)
                        .frame(width: 44, height: 44)
                        .buttonStyle(.glassProminent)
                        .disabled(!canSend)
                        .accessibilityIdentifier(AccessibilityID.chatSendButton)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
        }
        .padding(8)
        .frame(maxWidth: AppTheme.composerMaxWidth)
        .glassSurface(cornerRadius: 28, isInteractive: true)
        .frame(maxWidth: .infinity)
        .confirmationDialog("Add attachment", isPresented: $showingAttachmentOptions, titleVisibility: .visible) {
            if allowsImages {
                Button("Photo Library", systemImage: "photo") {
                    showingPhotoPicker = true
                }
                .accessibilityIdentifier(AccessibilityID.chatAttachmentPhotoButton)
            }

            if allowsFiles {
                Button("Files", systemImage: "doc") {
                    showingFileImporter = true
                }
                .accessibilityIdentifier(AccessibilityID.chatAttachmentFilesButton)
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Attach up to \(maxAttachmentCount) items.")
        }
        .photosPicker(
            isPresented: $showingPhotoPicker,
            selection: $selectedPhotoItems,
            maxSelectionCount: max(1, remainingAttachmentSlots),
            matching: .images
        )
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true,
            onCompletion: handleFileImport
        )
        .onChange(of: selectedPhotoItems) { _, newItems in
            loadPhotos(newItems)
        }
        .onChange(of: voiceInput.transcript) { _, transcript in
            applyVoiceTranscript(transcript)
        }
        .onDisappear {
            voiceInput.cancel()
        }
        .animation(AppMotion.quick, value: isRunning)
        .animation(AppMotion.standard, value: hasAttachments)
        .animation(AppMotion.quick, value: voiceInput.state)
        .animation(AppMotion.quick, value: attachmentError)
        .animation(AppMotion.quick, value: voiceInput.errorMessage)
        .animation(AppMotion.quick, value: shouldShowSkillPalette)
        .sensoryFeedback(.selection, trigger: feedbackTrigger)
        .sensoryFeedback(.error, trigger: errorFeedbackTrigger)
    }

    private var hasAttachments: Bool {
        !imageAttachments.isEmpty || !fileAttachments.isEmpty
    }

    private var allowsAttachments: Bool {
        allowsImages || allowsFiles
    }

    private var allowsImages: Bool {
        acceptedInputs?.images ?? true
    }

    private var allowsFiles: Bool {
        acceptedInputs?.files != nil || acceptedInputs == nil
    }

    private var maxAttachmentCount: Int {
        acceptedInputs?.files?.maxFilesPerRequest ?? AttachmentEncoding.defaultMaxAttachmentCount
    }

    private var maxFileSizeBytes: Int {
        (acceptedInputs?.files?.maxFileSizeMB ?? 10) * 1024 * 1024
    }

    private var maxImageEncodedBytes: Int {
        let frameBudget = AttachmentEncoding.defaultMaxInputFrameBytes - AttachmentEncoding.defaultInputFrameSafetyMarginBytes
        let perAttachmentBudget = frameBudget / max(1, maxAttachmentCount)
        let acceptedFileBudget = AttachmentEncoding.encodedDataURLSize(
            forRawByteCount: maxFileSizeBytes,
            mimeType: "image/jpeg"
        )
        return min(perAttachmentBudget, acceptedFileBudget)
    }

    private var maxInputFramePayloadBytes: Int {
        AttachmentEncoding.defaultMaxInputFrameBytes - AttachmentEncoding.defaultInputFrameSafetyMarginBytes
    }

    private var currentAttachmentCount: Int {
        imageAttachments.count + fileAttachments.count
    }

    private var remainingAttachmentSlots: Int {
        max(0, maxAttachmentCount - currentAttachmentCount)
    }

    private var canSend: Bool {
        !voiceInput.isActive && (!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || hasAttachments)
    }

    private var shouldShowSkillPalette: Bool {
        !voiceInput.isActive && !filteredSkills.isEmpty
    }

    private var skillQuery: String? {
        guard text.hasPrefix("/") else { return nil }
        return String(text.dropFirst().split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false).first ?? "")
    }

    private var filteredSkills: [SkillInfo] {
        guard let skillQuery else { return [] }
        return skills
            .filter { skill in
                skillQuery.isEmpty || skill.name.localizedCaseInsensitiveContains(skillQuery)
            }
            .prefix(6)
            .map { $0 }
    }

    private var voiceButtonTitle: String {
        voiceInput.state == .recording ? "Stop dictation" : "Start dictation"
    }

    private var voiceButtonSystemImage: String {
        switch voiceInput.state {
        case .requestingPermission, .transcribing:
            "waveform"
        case .recording:
            "stop.fill"
        case .idle:
            "mic.fill"
        }
    }

    private func showAttachmentMenu() {
        guard !voiceInput.isActive else { return }
        guard remainingAttachmentSlots > 0 else {
            showAttachmentError("Attachment limit reached")
            return
        }
        tick()
        showingAttachmentOptions = true
    }

    private func loadPhotos(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        let itemsToLoad = Array(items.prefix(remainingAttachmentSlots))

        Task {
            defer {
                Task { @MainActor in
                    selectedPhotoItems = []
                }
            }

            for item in itemsToLoad {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        await MainActor.run {
                            showAttachmentError("Could not read that image")
                        }
                        continue
                    }

                    await MainActor.run {
                        appendImage(data: data)
                    }
                } catch {
                    await MainActor.run {
                        showAttachmentError("Could not attach that image")
                    }
                }
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls.prefix(remainingAttachmentSlots) {
                appendFile(from: url)
            }
        case .failure:
            showAttachmentError("Could not open that file")
        }
    }

    private func appendFile(from url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            let contentType = UTType(filenameExtension: url.pathExtension)

            if allowsImages, contentType?.conforms(to: .image) == true {
                appendImage(data: data)
                return
            }

            guard validateAttachment(size: data.count) else { return }

            let file = AttachmentEncoding.fileAttachment(name: url.lastPathComponent, contentType: contentType, data: data)
            fileAttachments.append(file)
            attachmentError = nil
            tick()
        } catch {
            showAttachmentError("Could not attach \(url.lastPathComponent)")
        }
    }

    private func appendImage(data: Data) {
        guard remainingAttachmentSlots > 0 else {
            showAttachmentError("Attachment limit reached")
            return
        }

        guard let payload = AttachmentEncoding.imagePayload(data: data, maxEncodedBytes: maxImageEncodedBytes) else {
            showAttachmentError("Image is too large to send")
            return
        }

        guard validateAttachment(size: payload.size) else { return }
        imageAttachments.append(
            ImageAttachmentDraft(
                name: "Photo \(imageAttachments.count + 1).\(payload.filenameExtension)",
                size: payload.size,
                dataURL: payload.dataURL,
                image: payload.image
            )
        )
        attachmentError = nil
        tick()
    }

    private func validateAttachment(size: Int) -> Bool {
        guard remainingAttachmentSlots > 0 else {
            showAttachmentError("Attachment limit reached")
            return false
        }

        guard size <= maxFileSizeBytes else {
            showAttachmentError("Attachment is larger than \(formatFileSize(maxFileSizeBytes))")
            return false
        }

        return true
    }

    private func removeImage(_ id: UUID) {
        imageAttachments.removeAll { $0.id == id }
        attachmentError = nil
        tick()
    }

    private func removeFile(_ id: String) {
        fileAttachments.removeAll { $0.id == id }
        attachmentError = nil
        tick()
    }

    private func showAttachmentError(_ message: String) {
        attachmentError = message
        errorFeedbackTrigger += 1
    }

    private func toggleVoiceInput() {
        tick()
        switch voiceInput.state {
        case .recording:
            voiceInput.stopRecording()
        case .idle:
            voiceSeedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            isFocused = false
            voiceInput.startRecording()
        case .requestingPermission, .transcribing:
            break
        }
    }

    private func applyVoiceTranscript(_ transcript: String) {
        guard !transcript.isEmpty else { return }
        let separator = voiceSeedText.isEmpty ? "" : " "
        text = voiceSeedText + separator + transcript
    }

    private func selectSkill(_ skill: SkillInfo) {
        tick()
        text = "/\(skill.name) "
        isFocused = true
    }

    private func send() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !voiceInput.isActive, !trimmed.isEmpty || hasAttachments else { return }
        tick()
        let images = imageAttachments.map(\.dataURL)
        let files = fileAttachments
        let estimatedFrameBytes = AttachmentEncoding.estimatedInputFrameBytes(prompt: trimmed, images: images, files: files)
        guard estimatedFrameBytes <= maxInputFramePayloadBytes else {
            showAttachmentError("Message attachments are larger than \(formatFileSize(maxInputFramePayloadBytes))")
            return
        }

        text = ""
        imageAttachments = []
        fileAttachments = []
        attachmentError = nil
        onSend(trimmed, images, files)
    }

    private func stop() {
        tick()
        onStop()
    }

    private func tick() {
        feedbackTrigger += 1
    }
}

private struct VoiceInputStatusPill: View {
    var state: VoiceInputTranscriber.RecordingState
    var duration: TimeInterval
    var transcript: String

    var body: some View {
        HStack(spacing: 10) {
            voiceGlyph

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                if transcript.isEmpty {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(transcript)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .glassSurface(cornerRadius: 18, tint: state == .recording ? .red.opacity(0.08) : nil)
        .accessibilityIdentifier(AccessibilityID.chatVoiceStatus)
    }

    @ViewBuilder
    private var voiceGlyph: some View {
        switch state {
        case .recording:
            ZStack {
                Circle()
                    .fill(.red.opacity(0.18))
                    .frame(width: 24, height: 24)
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
            }
        case .requestingPermission, .transcribing:
            ProgressView()
                .controlSize(.small)
                .frame(width: 24, height: 24)
        case .idle:
            Image(systemName: "mic.fill")
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
        }
    }

    private var title: String {
        switch state {
        case .requestingPermission:
            "Preparing voice input"
        case .recording:
            "Listening \(formatVoiceDuration(duration))"
        case .transcribing:
            "Finishing transcript"
        case .idle:
            "Voice input"
        }
    }

    private var subtitle: String {
        switch state {
        case .requestingPermission:
            "Speech and microphone access may be requested."
        case .recording:
            "Speak naturally. Tap stop when you are done."
        case .transcribing:
            "Adding your words to the message."
        case .idle:
            ""
        }
    }
}

private struct SkillCommandPalette: View {
    var skills: [SkillInfo]
    var onSelect: (SkillInfo) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(skills) { skill in
                Button {
                    onSelect(skill)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("/\(skill.name)")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .frame(minWidth: 76, alignment: .leading)

                        Text(skill.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(AccessibilityID.chatSkill(skill.name))

                if skill.id != skills.last?.id {
                    Divider()
                        .padding(.leading, 12)
                }
            }
        }
        .glassSurface(cornerRadius: 18, isInteractive: true)
        .accessibilityIdentifier(AccessibilityID.chatSkillPalette)
    }
}

private struct ImageAttachmentDraft: Identifiable {
    let id: UUID
    var name: String
    var size: Int
    var dataURL: String
    var image: UIImage?

    init(id: UUID = UUID(), name: String, size: Int, dataURL: String, image: UIImage? = nil) {
        self.id = id
        self.name = name
        self.size = size
        self.dataURL = dataURL
        self.image = image
    }
}

private struct ComposerAttachmentPreviewStrip: View {
    var images: [ImageAttachmentDraft]
    var files: [FileAttachment]
    var onRemoveImage: (UUID) -> Void
    var onRemoveFile: (String) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(images) { image in
                    ImageAttachmentPreview(image: image, onRemove: onRemoveImage)
                }

                ForEach(files) { file in
                    FileAttachmentPreview(file: file, onRemove: onRemoveFile)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }
}

private struct ImageAttachmentPreview: View {
    var image: ImageAttachmentDraft
    var onRemove: (UUID) -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let uiImage = image.image {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "photo")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: 72, height: 72)
            .background(.quaternary)
            .clipShape(.rect(cornerRadius: 18))

            Button("Remove \(image.name)", systemImage: "xmark") {
                onRemove(image.id)
            }
            .labelStyle(.iconOnly)
            .font(.caption2.weight(.bold))
            .frame(width: 24, height: 24)
            .buttonStyle(.glass)
            .accessibilityIdentifier(AccessibilityID.attachmentRemove(image.id.uuidString))
            .offset(x: 6, y: -6)
        }
        .padding(.top, 6)
        .padding(.trailing, 6)
    }
}

private struct FileAttachmentPreview: View {
    var file: FileAttachment
    var onRemove: (String) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text(file.name)
                    .font(.footnote.weight(.medium))
                    .lineLimit(1)
                Text(formatFileSize(file.size))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Button("Remove \(file.name)", systemImage: "xmark") {
                onRemove(file.id)
            }
            .labelStyle(.iconOnly)
            .font(.caption2.weight(.bold))
            .frame(width: 24, height: 24)
            .buttonStyle(.glass)
            .accessibilityIdentifier(AccessibilityID.attachmentRemove(file.id))
        }
        .padding(.leading, 11)
        .padding(.trailing, 6)
        .padding(.vertical, 8)
        .glassSurface(cornerRadius: 16)
    }
}

private func formatFileSize(_ bytes: Int) -> String {
    if bytes < 1024 {
        return "\(bytes) B"
    }

    if bytes < 1024 * 1024 {
        return String(format: "%.1f KB", Double(bytes) / 1024)
    }

    return String(format: "%.1f MB", Double(bytes) / Double(1024 * 1024))
}

private func formatVoiceDuration(_ duration: TimeInterval) -> String {
    let totalSeconds = max(0, Int(duration.rounded(.down)))
    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60
    return "\(minutes):\(String(format: "%02d", seconds))"
}

#Preview("Chat Input Ready") {
    ChatInputBar(
        placeholder: "Message OpenOnion",
        isRunning: false,
        acceptedInputs: PreviewFixtures.sampleAgentInfo.acceptedInputs,
        skills: PreviewFixtures.sampleSkills,
        onSend: { _, _, _ in },
        onStop: {}
    )
    .padding()
}

#Preview("Chat Input Running") {
    ChatInputBar(
        placeholder: "Message OpenOnion",
        isRunning: true,
        acceptedInputs: PreviewFixtures.sampleAgentInfo.acceptedInputs,
        skills: PreviewFixtures.sampleSkills,
        onSend: { _, _, _ in },
        onStop: {}
    )
    .padding()
}

#Preview("Attachment Preview Strip") {
    ComposerAttachmentPreviewStrip(
        images: [
            ImageAttachmentDraft(
                name: "Photo 1.png",
                size: 2400,
                dataURL: "data:image/png;base64,iVBORw0KGgo="
            )
        ],
        files: PreviewFixtures.sampleFiles,
        onRemoveImage: { _ in },
        onRemoveFile: { _ in }
    )
    .padding()
}
