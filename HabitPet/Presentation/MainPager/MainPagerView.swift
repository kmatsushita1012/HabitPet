import SwiftUI

struct MainPagerView: View {
    @State private var viewModel = MainPagerViewModel()

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            Group {
                if viewModel.habits.isEmpty {
                    ContentUnavailableView(
                        "No Habits Yet",
                        systemImage: "pawprint",
                        description: Text("Tap + to create your first habit.")
                    )
                } else {
                    TabView(selection: $viewModel.selectedPageIndex) {
                        ForEach(Array(viewModel.habits.enumerated()), id: \.element.id) { index, habit in
                            VStack(spacing: 12) {
                                Text(habit.name)
                                    .font(.title2.bold())
                                Text("character: \(habit.characterIDRaw)")
                                    .foregroundStyle(.secondary)
                            }
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .onChange(of: viewModel.selectedPageIndex) { _, newValue in
                        viewModel.onPageChanged(newValue)
                    }
                }
            }
            .navigationTitle("HabitPet")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Edit") {
                        viewModel.onTapEdit()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.onTapAddPage()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .onAppear {
            viewModel.onAppear()
        }
    }
}

#Preview {
    MainPagerView()
}
