import Foundation
import SwiftData

@Model
final class TimeEntry {
    var id: UUID
    var startTime: Date
    var endTime: Date?
    var createdDate: Date
    
    @Relationship(deleteRule: .nullify)
    var task: Task?
    
    init(
        id: UUID = UUID(),
        startTime: Date = Date(),
        endTime: Date? = nil,
        createdDate: Date = Date(),
        task: Task? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.createdDate = createdDate
        self.task = task
    }
}
