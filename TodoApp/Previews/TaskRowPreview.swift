//
//  TaskRowPreview.swift
//  TodoApp
//
//  Created by Bjørn Emil Moy on 30/10/2025.
//
import SwiftUI
import SwiftData

#Preview("Task Rows - Various States") {
    func makeView() -> some View {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Task.self, Project.self, configurations: config)
        let context = ModelContext(container)
        
        // Create sample project
        let project = Project(title: "Work", color: "#007AFF")
        context.insert(project)
        
        // 1. Simple task
        let simpleTask = Task(
            title: "Simple task with no metadata",
            priority: 2,
            createdDate: Date(),
            project: project
        )
        context.insert(simpleTask)
        
        // 2. Task with due date
        let dueDateTask = Task(
            title: "Task due tomorrow",
            priority: 1,
            dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
            createdDate: Date(),
            project: project
        )
        context.insert(dueDateTask)
        
        // 3. Task with subtasks
        let parentTask = Task(
            title: "Parent task with subtasks",
            priority: 0,
            createdDate: Date(),
            project: project
        )
        context.insert(parentTask)
        
        let subtask1 = Task(
            title: "Subtask 1",
            priority: 2,
            completedDate: Date(), createdDate: Date(),
            parentTask: parentTask,
            project: project
        )
        context.insert(subtask1)
        
        let subtask2 = Task(
            title: "Subtask 2",
            priority: 2,
            createdDate: Date(),
            parentTask: parentTask,
            project: project
        )
        context.insert(subtask2)
        
        // 4. Task with time estimate
        let estimateTask = Task(
            title: "Task with time estimate",
            priority: 2,
            createdDate: Date(),
            project: project,
            estimatedSeconds: 120 * 60
        )
        context.insert(estimateTask)
        
        // 5. Overdue task
        let overdueTask = Task(
            title: "Overdue task",
            priority: 1,
            dueDate: Calendar.current.date(byAdding: .day, value: -2, to: Date()),
            createdDate: Date(),
            project: project
        )
        context.insert(overdueTask)
        
        // 6. Completed task
        let completedTask = Task(
            title: "Completed task",
            priority: 2,
            completedDate: Date(), createdDate: Date(),
            project: project
        )
        context.insert(completedTask)
        
        // 7. Long title task
        let longTask = Task(
            title: "This is a really long task title that should wrap to multiple lines to test the layout",
            priority: 0,
            dueDate: Date(),
            createdDate: Date(),
            project: project,
            estimatedSeconds: 180 * 60
        )
        context.insert(longTask)
        
        return NavigationStack {
            List {
                TaskRowView(task: simpleTask)
                TaskRowView(task: dueDateTask)
                TaskRowView(task: parentTask)
                TaskRowView(task: estimateTask)
                TaskRowView(task: overdueTask)
                TaskRowView(task: completedTask)
                TaskRowView(task: longTask)
            }
            .navigationTitle("Task Row Previews")
        }
        .modelContainer(container)
    }
    return makeView()
}

#Preview("Single Task - Expanded") {
    func makeView() -> some View {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Task.self, Project.self, configurations: config)
        let context = ModelContext(container)
        
        let project = Project(title: "Design", color: "#FF9500")
        context.insert(project)
        
        let task = Task(
            title: "Design mockups for new feature",
            priority: 1,
            dueDate: Calendar.current.date(byAdding: .hour, value: 3, to: Date()),
            createdDate: Date(),
            project: project,
            estimatedSeconds: 240 * 60
        )
        context.insert(task)
        
        let sub1 = Task(
            title: "Create wireframes",
            priority: 2,
            completedDate: Date(), createdDate: Date(),
            parentTask: task,
            project: project
        )
        context.insert(sub1)
        
        let sub2 = Task(
            title: "Design hi-fi mockups",
            priority: 1,
            createdDate: Date(),
            parentTask: task,
            project: project
        )
        context.insert(sub2)
        
        let sub3 = Task(
            title: "Get stakeholder feedback",
            priority: 2,
            createdDate: Date(),
            parentTask: task,
            project: project
        )
        context.insert(sub3)
        
        return NavigationStack {
            List {
                TaskRowView(task: task)
            }
            .navigationTitle("Expanded Task")
        }
        .modelContainer(container)
    }
    return makeView()
}

#Preview("Compact Screen") {
    func makeView() -> some View {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Task.self, Project.self, configurations: config)
        let context = ModelContext(container)
        
        let project = Project(title: "Mobile", color: "#34C759")
        context.insert(project)
        
        let task = Task(
            title: "Fix responsive layout bug on small screens",
            priority: 0,
            dueDate: Date(),
            createdDate: Date(),
            project: project,
            estimatedSeconds: 90 * 60
        )
        context.insert(task)
        
        return NavigationStack {
            List {
                TaskRowView(task: task)
            }
            .navigationTitle("Compact")
        }
        .modelContainer(container)
    }
    return makeView()
}

