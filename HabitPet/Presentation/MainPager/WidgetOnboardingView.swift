import AVFoundation
import AVKit
import SwiftUI

struct WidgetOnboardingView: View {
    let onDismissForLater: () -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .center, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ホーム画面に追加すると、もっと続けやすくなります")
                            .font(.title2.bold())
                    }
                    .frame(maxWidth: .infinity)

                    LoopingVideoPlayerView(resourceName: "Widget", resourceExtension: "mp4")
                        .frame(height: 540)

                    VStack(alignment: .leading, spacing: 14) {
                        Text("追加手順")
                            .font(.headline)

                        WidgetOnboardingStepRow(
                            number: 1,
                            text: "ホーム画面を長押しする"
                        )
                        WidgetOnboardingStepRow(
                            number: 2,
                            text: "表示された編集ボタンを押す"
                        )
                        WidgetOnboardingStepRow(
                            number: 3,
                            text: "「ウィジェットを追加」を押す"
                        )
                        WidgetOnboardingStepRow(
                            number: 4,
                            text: "一覧から「もふデトックス」を選ぶ"
                        )
                        WidgetOnboardingStepRow(
                            number: 5,
                            text: "「ウィジェットを追加」を押す"
                        )
                        WidgetOnboardingStepRow(
                            number: 6,
                            text: "ホーム画面右上の「完了」を押す"
                        )
                    }
                    .padding(20)
                    .background(.background, in: .rect(cornerRadius: 20, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(.quaternary, lineWidth: 1)
                    }

                    VStack(spacing: 12) {
                        Button {
                            onDismissForLater()
                        } label: {
                            Text("あとで見る")
                                .padding(8)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            onClose()
                        } label: {
                            Text("閉じる")
                                .padding(8)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Widget を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }
}

private struct WidgetOnboardingStepRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .frame(width: 30, height: 30)
                .background(Color.green.opacity(0.14), in: Circle())
                .foregroundStyle(.green)

            Text(text)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct LoopingVideoPlayerView: View {
    let resourceName: String
    let resourceExtension: String
    @State private var player: AVPlayer?
    @State private var endObserver: NSObjectProtocol?
    @State private var ratio = CGFloat(9 / 16.0)

    var body: some View {
        Group {
            if let player {
                VideoPlayer(player: player)
                    .aspectRatio(ratio, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 36))
                       .overlay(
                           RoundedRectangle(cornerRadius: 36)
                            .stroke(Color.gray, lineWidth: 2)
                       )
                    .allowsHitTesting(false)
                    .onAppear {
                        configureAudioSession()
                        player.play()
                        installLoopObserverIfNeeded(for: player)
                    }
                    .onDisappear {
                        player.pause()
                        removeLoopObserver()
                        deactivateAudioSession()
                    }
            } else {
                Color.clear
                    .aspectRatio(9.0 / 16.0, contentMode: .fit)
            }
        }
        .task {
            guard player == nil else { return }
            guard let url = Bundle.main.url(forResource: resourceName, withExtension: resourceExtension) else { return }
            let createdPlayer = AVPlayer(url: url)
            createdPlayer.isMuted = true
            createdPlayer.volume = 0
            player = createdPlayer
            self.ratio = (try? await getAspectRatio(from: createdPlayer)) ?? ratio
        }
    }

    private func installLoopObserverIfNeeded(for player: AVPlayer) {
        guard endObserver == nil else { return }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }
    }

    private func removeLoopObserver() {
        guard let endObserver else { return }
        NotificationCenter.default.removeObserver(endObserver)
        self.endObserver = nil
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    private func deactivateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: [.notifyOthersOnDeactivation])
    }
    
    private func getAspectRatio(from player: AVPlayer) async throws -> CGFloat? {
        guard let item = player.currentItem else { return nil }
        guard let track = try await item.asset.loadTracks(withMediaType: .video).first else { return nil }
        
        let size = try await track.load(.naturalSize)
        let transform = try await track.load(.preferredTransform)
        
        // 回転を考慮したサイズ
        let transformedSize = size.applying(transform)
        
        let width = abs(transformedSize.width)
        let height = abs(transformedSize.height)
        
        guard height != 0 else { return nil }
        
        return width / height
    }
}

#Preview {
    WidgetOnboardingView(
        onDismissForLater: { return () },
        onClose: { return () }
    )
}
