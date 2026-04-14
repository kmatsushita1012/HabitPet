import SwiftUI
import UIKit

struct InitialOnboardingView: View {
    let onStart: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.95, green: 0.91, blue: 0.85),
                        Color(red: 0.90, green: 0.82, blue: 0.72),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("もふデトックス")
                                .font(.headline)
                                .foregroundStyle(Color(red: 0.39, green: 0.29, blue: 0.20))

                            Text("悪習慣を記録すると、\nペットの様子が変わります")
                                .font(.largeTitle.bold())
                                .foregroundStyle(Color(red: 0.22, green: 0.16, blue: 0.10))

                            Text("まずは 1 つ作って始めましょう。")
                                .font(.body)
                                .foregroundStyle(Color(red: 0.39, green: 0.29, blue: 0.20))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        InitialOnboardingHeroView()

                        VStack(alignment: .leading, spacing: 10) {
                            InitialOnboardingLine(text: "記録すると、ペットの見た目で変化が分かります")
                            InitialOnboardingLine(text: "作成後に Widget の追加方法も案内します")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Button {
                            onStart()
                        } label: {
                            Text("はじめよう")
                                .font(.headline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        .buttonStyle(.glassProminent)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 32)
                }
            }
            .toolbarVisibility(.hidden, for: .navigationBar)
        }
    }
}

private struct InitialOnboardingHeroView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.55),
                            Color(red: 0.93, green: 0.87, blue: 0.78).opacity(0.92),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            VStack(spacing: 14) {
                OnboardingPetImage()
                    .frame(width: 260, height: 195)

                Text("ホームでも、もふっと見守ります")
                    .font(.headline)
                    .foregroundStyle(Color(red: 0.30, green: 0.22, blue: 0.15))
            }
            .padding(24)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.45), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.06), radius: 16, x: 0, y: 10)
    }
}

private struct OnboardingPetImage: View {
    var body: some View {
        let names = habitCharacterAssetNames(kind: .nonSmoking, character: .hamster, level: 1)

        ZStack {
            if let image = OnboardingCharacterImageLoader.load(named: names) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "pawprint.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
                    .padding(30)
            }
        }
        .clipShape(.rect(cornerRadius: 20, style: .continuous))
    }
}

private struct InitialOnboardingLine: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "pawprint.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color(red: 0.39, green: 0.29, blue: 0.20))
                .padding(.top, 4)

            Text(text)
                .font(.body)
                .foregroundStyle(Color(red: 0.24, green: 0.18, blue: 0.12))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private enum OnboardingCharacterImageLoader {
    static func load(named candidates: [String]) -> UIImage? {
        for name in candidates {
            if let image = UIImage(named: name) {
                return image
            }
        }
        return nil
    }
}
