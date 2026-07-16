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
    @State private var showingCamera = false
    @State private var pendingPicker: PendingPicker?
    @State private var attachmentError: String?
    @State private var voiceSeedText = ""
    @State private var voiceOriginalText = "" // exact pre-dictation text, restored on ✕
    @State private var voiceLastApplied = "" // last text written from a transcript, to detect manual edits
    @State private var feedbackTrigger = 0
    @State private var errorFeedbackTrigger = 0
    @FocusState private var isFocused: Bool

    /// Which picker the attachment sheet asked for — presented from the sheet's `onDismiss` so the two
    /// modal transitions never overlap.
    private enum PendingPicker { case camera, photos, files }

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

            if shouldShowSkillPalette {
                SkillCommandPalette(skills: filteredSkills, onSelect: selectSkill)
                    .transition(AppMotion.panelTransition)
            }

            // Row 1: the text field spans the full width. It stays visible during dictation so the
            // streaming transcript is readable while the keyboard remains up.
            TextField("", text: $text, axis: .vertical)
                .lineLimit(1...6)
                .textFieldStyle(.plain)
                .tint(.primary)
                .focused($isFocused)
                .submitLabel(.send)
                .onSubmit(send)
                // Custom placeholder: the system placeholder (~30% white) is nearly invisible on the
                // dark glass bar. A concrete light gray reads clearly and resists the glass vibrancy.
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(placeholder)
                            .foregroundStyle(Color(.systemGray))
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.top, 8)
                .accessibilityIdentifier(AccessibilityID.chatInput)

            if voiceInput.isActive {
                // Row 2 (dictation): cancel ✕, live waveform, confirm ✓.
                VoiceRecordingBar(
                    voice: voiceInput,
                    onCancel: cancelVoiceInput,
                    onConfirm: confirmVoiceInput
                )
                .transition(.opacity)
            } else {
                // Row 2: attach on the left, mic + send (or stop) on the right.
                HStack(spacing: 10) {
                    if allowsAttachments {
                        Button("Add attachment", systemImage: "plus", action: showAttachmentMenu)
                            .labelStyle(.iconOnly)
                            .frame(width: 38, height: 38)
                            .buttonStyle(.glass)
                            .disabled(remainingAttachmentSlots == 0)
                            .accessibilityIdentifier(AccessibilityID.chatAttachmentButton)
                    }

                    Spacer(minLength: 0)

                    if isRunning {
                        Button("Stop", systemImage: "stop.fill", action: stop)
                            .labelStyle(.iconOnly)
                            .frame(width: 40, height: 40)
                            .buttonStyle(.glass)
                            .accessibilityIdentifier(AccessibilityID.chatStopButton)
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    } else {
                        Button(voiceButtonTitle, systemImage: voiceButtonSystemImage, action: toggleVoiceInput)
                            .labelStyle(.iconOnly)
                            .frame(width: 40, height: 40)
                            .buttonStyle(.glass)
                            .accessibilityIdentifier(AccessibilityID.chatVoiceButton)

                        Button("Send", systemImage: "arrow.up", action: send)
                            .labelStyle(.iconOnly)
                            .frame(width: 40, height: 40)
                            .buttonStyle(.glassProminent)
                            .disabled(!canSend)
                            .accessibilityIdentifier(AccessibilityID.chatSendButton)
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: AppTheme.composerMaxWidth)
        // The bar is a container, not a control — `.interactive()` glass here rests in a dim/flat state
        // and only "wakes up" (renders the full material, placeholder legible) once it's touched. Plain
        // regular glass renders correctly from first appearance. The inner buttons stay interactive.
        .glassSurface(cornerRadius: 28)
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $showingAttachmentOptions, onDismiss: presentPendingPicker) {
            AttachmentSheet(
                allowsImages: allowsImages,
                allowsFiles: allowsFiles,
                maxPhotoSelection: remainingAttachmentSlots,
                onCamera: { pendingPicker = .camera },
                onAllPhotos: { pendingPicker = .photos },
                onPhotosData: { datas in attachImages(datas) },
                onPhotoError: { message in showAttachmentError(message) },
                onFiles: { pendingPicker = .files }
            )
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker { data in appendImage(data: data) }
                .ignoresSafeArea()
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

    /// Attach several picked photos at once. Checks the live slot count each iteration so an image
    /// that `appendImage` rejects (e.g. too large) doesn't waste a slot, and stops with a single
    /// "limit reached" note if we genuinely run out.
    private func attachImages(_ datas: [Data]) {
        for data in datas {
            guard remainingAttachmentSlots > 0 else {
                showAttachmentError("Attachment limit reached")
                return
            }
            appendImage(data: data)
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
            voiceOriginalText = text // exact text (incl. trailing whitespace) for ✕ restore
            voiceSeedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            voiceLastApplied = text
            isFocused = true // keep the keyboard up; the transcript streams into the field live
            voiceInput.startRecording()
        case .requestingPermission, .transcribing:
            break
        }
    }

    private func applyVoiceTranscript(_ transcript: String) {
        guard !transcript.isEmpty else { return }
        // Only overwrite the field if the user hasn't manually edited it since our last write; otherwise
        // a streaming partial would clobber what they just typed.
        guard text == voiceLastApplied else { return }
        let separator = voiceSeedText.isEmpty ? "" : " "
        let merged = voiceSeedText + separator + transcript
        text = merged
        voiceLastApplied = merged
    }

    /// ✓ — keep the dictated text: stop recording so the final transcript settles into the field.
    private func confirmVoiceInput() {
        tick()
        if voiceInput.state == .recording {
            voiceInput.stopRecording()
        }
    }

    /// ✕ — discard the dictation and restore exactly what was in the field before recording started.
    private func cancelVoiceInput() {
        tick()
        voiceInput.cancel()
        text = voiceOriginalText
    }

    /// Present whichever picker the attachment sheet requested, now that the sheet has fully dismissed
    /// (called from the sheet's `onDismiss`, so the host view is free to present the next modal).
    private func presentPendingPicker() {
        guard let picker = pendingPicker else { return }
        pendingPicker = nil
        switch picker {
        case .camera: showingCamera = true
        case .photos: showingPhotoPicker = true
        case .files: showingFileImporter = true
        }
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

