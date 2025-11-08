import Foundation
import SwiftData

@Model
final class TimeEntry {
    var id: UUID
    var startTime: Date
    var endTime: Date?
    var createdDate: Date
    var personnelCount: Int  // Number of people working (default: 1 for solo work)

    @Relationship(deleteRule: .nullify)
    var task: Task?

    init(
        id: UUID = UUID(),
        startTime: Date = Date(),
        endTime: Date? = nil,
        createdDate: Date = Date(),
        personnelCount: Int = 1,
        task: Task? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.createdDate = createdDate
        self.personnelCount = personnelCount
        self.task = task
    }
}
