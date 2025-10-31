import Foundation
import SwiftData

@Model
final class Project {
    var id: UUID
    var title: String
    var color: String
    var createdDate: Date
    var order: Int?  // FIXED: Made optional to support migration
    
    @Relationship(deleteRule: .cascade, inverse: \Task.project)
    var tasks: [Task]?
    
    init(
        id: UUID = UUID(),
        title: String,
        color: String,
        createdDate: Date = Date(),
        order: Int? = nil  // FIXED: Optional with nil default
    ) {
        self.id = id
        self.title = title
        self.color = color
        self.createdDate = createdDate
        self.order = order ?? 0  // FIXED: Provide 0 if nil
        self.tasks = nil
    }
    
    // MARK: - Computed Properties
    
    @Transient
    var orderValue: Int {
        order ?? 0  // FIXED: Computed property for safe access
    }
    
    @Transient
    var incompleteTasks: Int {
        tasks?.filter { !$0.isCompleted }.count ?? 0
    }
    
    @Transient
    var completedTasks: Int {
        tasks?.filter { $0.isCompleted }.count ?? 0
    }
    
    @Transient
    var totalTimeSpent: Int {
        tasks?.reduce(0) { $0 + $1.totalTimeSpent } ?? 0
    }
}
