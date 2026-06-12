import Foundation
import SwiftData

struct SeedDataFactory {
    /// 首次启动时注入种子数据（如果数据库为空）
    /// - Parameter context: SwiftData ModelContext
    static func seedIfNeeded(context: ModelContext) {
        // 1. 查询当前 Project 数量
        let descriptor = FetchDescriptor<Project>()
        let count = (try? context.fetchCount(descriptor)) ?? 0

        // 2. 如果已有数据，直接返回
        if count == 0 {
            // 3. 创建演示项目
            _ = MockDataFactory.createDemoProject(context: context)
        }

        MockDataFactory.ensureCompletedDemoProject(context: context)

        // 4. 保存
        try? context.save()
    }
}
