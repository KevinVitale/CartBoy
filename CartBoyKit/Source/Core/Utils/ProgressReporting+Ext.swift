import Foundation

extension ProgressReporting {
    func resetProgress(to totalUnitCount: Int64) {
        progress.completedUnitCount = 0
        progress.totalUnitCount = totalUnitCount
    }
}
