//
//  ContentView.swift
//  CoDesign-Agent
//
//  Created by mac on 2026/5/28.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(sort: \Project.updatedAt, order: .reverse) private var projects: [Project]

    var body: some View {
        NavigationStack {
            List {
                ForEach(projects) { project in
                    NavigationLink {
                        Text("项目详情（Step 14 实现）")
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(project.name)
                                .font(.headline)
                            Text(project.briefDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack {
                                Text("完成度: \(Int(project.completionRate * 100))%")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                Spacer()
                                Text("\(project.messages.count) 条对话")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete(perform: deleteProjects)
            }
            .navigationTitle("Clarify")
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                #endif
            }
        }
    }

    private func deleteProjects(offsets: IndexSet) {
        // 暂时留空，Step 13 实现完整逻辑
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Project.self, inMemory: true)
}
