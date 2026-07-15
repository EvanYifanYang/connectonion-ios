import SwiftUI

struct EvaluationRow: View {
    var item: ChatItem

    var body: some View {
        StatusPill(
            systemImage: item.status == .done ? (item.passed == true ? "checkmark.seal" : "xmark.seal") : "checklist",
            text: item.content.nilIfEmpty ?? item.expected ?? "Evaluating",
            tint: item.passed == false ? .red : .green
        )
    }
}

#Preview("Evaluation Passed") {
    EvaluationRow(item: PreviewFixtures.sampleEvaluation)
        .padding()
}

#Preview("Evaluation Failed") {
    EvaluationRow(item: PreviewFixtures.sampleEvaluationFailed)
        .padding()
}
