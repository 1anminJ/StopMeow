import SwiftUI

/// 팝오버 뼈대. 실제 설정(On/Off, 알림 토글, 방해 강도)은 미구현.
struct PopoverView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("멈춰묘").font(.headline)
            Text("설정은 아직 준비 중이에요.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("종료") { NSApp.terminate(nil) }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
