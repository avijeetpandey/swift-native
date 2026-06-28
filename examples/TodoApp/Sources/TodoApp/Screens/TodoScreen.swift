import SwiftNativeCore

struct Task: Identifiable {
    let id: Int
    var title: String
}

struct TodoScreen: View {
    @State private var tasks: [Task] = [
        Task(id: 1, title: "Learn Swift Native"),
        Task(id: 2, title: "Build a todo app"),
    ]
    @State private var nextID = 3

    var body: some View {
        VStack(spacing: 12) {
            Text("To-do (\(tasks.count))")
                .font(.title)
                .foregroundColor(.blue)

            Button("Add Task") {
                tasks.append(Task(id: nextID, title: "Task \(nextID)"))
                nextID += 1
            }

            List {
                ForEach(tasks) { task in
                    HStack {
                        Text(task.title)
                        Spacer()
                        Button("Delete") {
                            tasks.removeAll { $0.id == task.id }
                        }
                    }
                    .padding(8)
                }
            }
        }
        .padding(24)
    }
}
