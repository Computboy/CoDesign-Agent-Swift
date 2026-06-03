import Foundation

struct FrontierPaperSearchService {
    private struct SearchResponse: Decodable {
        let data: [Paper]
    }

    private struct Paper: Decodable {
        let paperId: String
        let title: String
        let abstract: String?
        let year: Int?
        let venue: String?
        let url: String?
        let authors: [Author]?
    }

    private struct Author: Decodable {
        let name: String
    }

    func searchPapers(
        stageOrder: Int,
        brief: DesignBrief?,
        recentMessage: String?,
        limit: Int = 3
    ) async throws -> [ResourceCard] {
        let semanticScholarResults = try await searchSemanticScholar(
            stageOrder: stageOrder,
            brief: brief,
            recentMessage: recentMessage,
            limit: limit
        )
        if !semanticScholarResults.isEmpty {
            return semanticScholarResults
        }

        return try await searchArxiv(
            stageOrder: stageOrder,
            brief: brief,
            recentMessage: recentMessage,
            limit: limit
        )
    }

    private func searchSemanticScholar(
        stageOrder: Int,
        brief: DesignBrief?,
        recentMessage: String?,
        limit: Int
    ) async throws -> [ResourceCard] {
        let query = buildQuery(stageOrder: stageOrder, brief: brief, recentMessage: recentMessage)
        var components = URLComponents(string: "https://api.semanticscholar.org/graph/v1/paper/search")!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "fields", value: "title,abstract,year,venue,url,authors")
        ]

        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("CoDesign-Agent Course Assistant", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            return []
        }

        let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
        let terms = topicTerms(brief: brief, recentMessage: recentMessage)
        return decoded.data
            .filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .filter { isRelevantPaper(title: $0.title, summary: $0.abstract, topicTerms: terms) }
            .prefix(limit)
            .map { paper in
                let reading = paperReading(
                    title: paper.title,
                    summary: paper.abstract,
                    stageOrder: stageOrder,
                    brief: brief,
                    recentMessage: recentMessage
                )
                return ResourceCard(
                    id: "semantic-scholar-\(paper.paperId)",
                    title: paper.title,
                    type: .paper,
                    relatedStages: [stageOrder],
                    tags: ["前沿论文", "研究", "证据"],
                    summary: summarize(paper.abstract),
                    whyRelevant: reading.why,
                    howToUse: reading.how,
                    sourceURL: paper.url.flatMap(URL.init(string:)),
                    year: paper.year,
                    venue: paper.venue
                )
            }
    }

    private func searchArxiv(
        stageOrder: Int,
        brief: DesignBrief?,
        recentMessage: String?,
        limit: Int
    ) async throws -> [ResourceCard] {
        let query = buildArxivQuery(stageOrder: stageOrder, brief: brief, recentMessage: recentMessage)
        var components = URLComponents(string: "https://export.arxiv.org/api/query")!
        components.queryItems = [
            URLQueryItem(name: "search_query", value: query),
            URLQueryItem(name: "start", value: "0"),
            URLQueryItem(name: "max_results", value: "\(limit)"),
            URLQueryItem(name: "sortBy", value: "submittedDate"),
            URLQueryItem(name: "sortOrder", value: "descending")
        ]

        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("CoDesign-Agent Course Assistant", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            return []
        }

        let parser = ArxivFeedParser()
        let terms = topicTerms(brief: brief, recentMessage: recentMessage)
        return parser.parse(data: data)
            .filter { isRelevantPaper(title: $0.title, summary: $0.summary, topicTerms: terms) }
            .prefix(limit)
            .map { paper in
                let reading = paperReading(
                    title: paper.title,
                    summary: paper.summary,
                    stageOrder: stageOrder,
                    brief: brief,
                    recentMessage: recentMessage
                )
                return ResourceCard(
                    id: "arxiv-\(paper.id)",
                    title: paper.title,
                    type: .paper,
                    relatedStages: [stageOrder],
                    tags: ["前沿论文", "arXiv", "研究", "证据"],
                    summary: summarize(paper.summary),
                    whyRelevant: reading.why,
                    howToUse: reading.how,
                    sourceURL: URL(string: paper.link),
                    year: paper.year,
                    venue: "arXiv"
                )
            }
    }

    private func buildQuery(stageOrder: Int, brief: DesignBrief?, recentMessage: String?) -> String {
        let topicTerms = topicTerms(brief: brief, recentMessage: recentMessage)
        if topicTerms.count >= 2 {
            return semanticScholarQuery(from: topicTerms)
        }

        let stageTerms: String
        switch stageOrder {
        case 1: stageTerms = "design thinking wicked problem user pain point scenario"
        case 2: stageTerms = "design value proposition differentiation human centered design"
        case 3: stageTerms = "AI product boundary assumption mapping responsible AI design"
        case 4: stageTerms = "interaction design progressive disclosure AI interface"
        case 5: stageTerms = "persona user journey map design education"
        case 6: stageTerms = "design evaluation criteria feedback loop usability metrics"
        case 7: stageTerms = "human AI interaction feasibility AI design guidelines"
        case 8: stageTerms = "design risk assumption mapping human AI systems"
        case 9: stageTerms = "reflective practice design education portfolio"
        default: stageTerms = "human centered design AI design education"
        }

        let projectTerms = [
            brief?.targetUser,
            brief?.painPoint,
            brief?.useScenario,
            brief?.coreValue,
            recentMessage
        ]
            .compactMap { $0 }
            .joined(separator: " ")
            .prefix(180)

        let combined = "\(stageTerms) \(projectTerms)"
        return String(combined).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func buildArxivQuery(stageOrder: Int, brief: DesignBrief?, recentMessage: String?) -> String {
        let topic = topicTerms(brief: brief, recentMessage: recentMessage)
        if topic.count >= 2 {
            return arxivQuery(from: topic)
        }

        let fallback: [String]
        switch stageOrder {
        case 1: fallback = ["user", "pain", "scenario"]
        case 2: fallback = ["value", "proposition", "design"]
        case 3: fallback = ["assumption", "mapping", "design"]
        case 4: fallback = ["interaction", "design", "prototype"]
        case 5: fallback = ["persona", "user", "journey"]
        case 6: fallback = ["usability", "metrics", "feedback"]
        case 7: fallback = ["human", "AI", "interaction"]
        case 8: fallback = ["risk", "assumption", "AI"]
        case 9: fallback = ["reflective", "practice", "design"]
        default: fallback = ["human", "AI", "design"]
        }
        return fallback.map { "all:\($0)" }.joined(separator: " AND ")
    }

    private func summarize(_ abstract: String?) -> String {
        guard let abstract, !abstract.isEmpty else {
            return "联网检索到的相关研究，可作为当前设计判断的外部依据。"
        }
        let sentence = abstract
            .split(separator: ".")
            .prefix(2)
            .joined(separator: ". ")
        return sentence.isEmpty ? String(abstract.prefix(160)) : sentence + "."
    }

    private func semanticScholarQuery(from terms: [String]) -> String {
        if terms.contains("video"), terms.contains("AI") {
            return "AI video generation text-to-video controllable video"
        }
        if terms.contains("eeg"), terms.contains("music") {
            return "EEG music personalized generation brain computer music"
        }
        return terms.prefix(6).joined(separator: " ")
    }

    private func arxivQuery(from terms: [String]) -> String {
        if terms.contains("video"), terms.contains("AI") {
            return ["AI", "video", "generation"].map { "all:\($0)" }.joined(separator: " AND ")
        }
        if terms.contains("eeg"), terms.contains("music") {
            var required = ["eeg", "music"]
            if terms.contains("personalized") {
                required.append("personalized")
            }
            return required.prefix(4).map { "all:\($0)" }.joined(separator: " AND ")
        }
        return terms.prefix(4).map { "all:\($0)" }.joined(separator: " AND ")
    }

    private func paperReading(
        title: String,
        summary: String?,
        stageOrder: Int,
        brief: DesignBrief?,
        recentMessage: String?
    ) -> (why: String, how: String) {
        let terms = topicTerms(brief: brief, recentMessage: recentMessage)
        let readableTerms = readableTopicTerms(from: terms)
        let concepts = paperConcepts(title: title, summary: summary)
        let limitation = paperLimitation(summary)
        let focus = concepts.isEmpty ? "论文摘要中的问题定义、方法路径和评估方式" : concepts.joined(separator: "、")
        let projectTopic = readableTerms.isEmpty ? "你的项目主题" : readableTerms

        let why = "这篇论文的重点是\(focus)。它和\(projectTopic)的关系在于：它不是只展示一个生成结果，而是在说明系统如何接收输入、控制生成过程，并验证输出是否稳定或有用。\(limitation)"

        let how: String
        if concepts.contains("文本到视频生成") || concepts.contains("视频生成") || terms.contains("video") {
            how = "读这篇时重点摘出三件事：它让用户输入什么、能控制视频的哪些维度、用什么指标判断视频质量。然后把这三点改写成你的项目边界：第一版到底生成哪类视频、服务哪个场景、哪些生成能力暂时不做。"
        } else if concepts.contains("脑电信号") || concepts.contains("音乐生成") || terms.contains("eeg") {
            how = "读这篇时重点看它如何把生理信号转成音乐控制参数，以及它承认哪些信号不稳定。然后把这些内容转成你的项目假设：脑电能否可靠识别状态、音乐如何个性化、失败时如何反馈给用户。"
        } else {
            how = "读这篇时不要只引用标题，先提取它的研究对象、方法步骤、评价方式和限制，再对应到你的项目里：哪些可以作为证据，哪些反而提醒你要收窄范围。"
        }

        return (why, how)
    }

    private func topicTerms(brief: DesignBrief?, recentMessage: String?) -> [String] {
        let text = [
            brief?.project?.name,
            brief?.targetUser,
            brief?.painPoint,
            brief?.useScenario,
            brief?.coreValue,
            brief?.mvpFeatures,
            recentMessage
        ]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()

        var terms: [String] = []
        func add(_ term: String) {
            if !terms.contains(term) {
                terms.append(term)
            }
        }

        if text.contains("脑电") || text.contains("脑波") || text.contains("eeg") || text.contains("brainwave") || text.contains("brain wave") {
            add("eeg")
        }
        if text.contains("脑机") || text.contains("bci") || text.contains("brain-computer") {
            add("brain-computer")
        }
        if text.contains("视频") || text.contains("影像") || text.contains("短片") || text.contains("video") || text.contains("text-to-video") || text.contains("text to video") {
            add("video")
        }
        if text.contains("音乐") || text.contains("music") || text.contains("音频") || text.contains("audio") {
            add("music")
        }
        if text.contains("个性") || text.contains("personal") || text.contains("定制") || text.contains("personalized") {
            add("personalized")
        }
        if text.contains("生成") || text.contains("generator") || text.contains("generation") || text.contains("generative") {
            add("generation")
        }
        if text.contains("情绪") || text.contains("放松") || text.contains("压力") || text.contains("emotion") || text.contains("stress") || text.contains("relax") {
            add("emotion")
        }
        if text.contains("助眠") || text.contains("睡眠") || text.contains("sleep") {
            add("sleep")
        }
        if text.contains("学生") || text.contains("学习") || text.contains("student") {
            add("student")
        }
        if text.contains("ai") || text.contains("人工智能") || text.contains("大模型") || text.contains("llm") {
            add("AI")
        }
        if terms.contains("video"), terms.contains("AI"), !terms.contains("generation") {
            add("generation")
        }

        return terms
    }

    private func readableTopicTerms(from terms: [String]) -> String {
        let mapped = terms.prefix(4).map { term in
            switch term {
            case "eeg": return "脑电信号"
            case "brain-computer": return "脑机接口"
            case "video": return "AI 视频"
            case "music": return "音乐体验"
            case "personalized": return "个性化"
            case "generation": return terms.contains("video") ? "生成式视频" : "生成式音乐"
            case "emotion": return "情绪调节"
            case "sleep": return "睡眠/放松场景"
            case "student": return "学生用户"
            case "AI": return "AI 系统"
            default: return term
            }
        }
        return mapped.joined(separator: "、")
    }

    private func stageFocusText(_ stageOrder: Int) -> String {
        switch stageOrder {
        case 1: return "痛点与使用场景"
        case 2: return "差异化价值"
        case 3: return "项目边界"
        case 4: return "功能与技术拆解"
        case 5: return "用户画像和行为路径"
        case 6: return "评价标准"
        case 7: return "技术可行性"
        case 8: return "风险与假设"
        case 9: return "下一步迭代"
        default: return "设计判断"
        }
    }

    private func paperConcepts(title: String, summary: String?) -> [String] {
        let text = "\(title) \(summary ?? "")".lowercased()
        var concepts: [String] = []
        func add(_ concept: String) {
            if !concepts.contains(concept) {
                concepts.append(concept)
            }
        }

        if text.contains("text-to-video") || text.contains("text to video") {
            add("文本到视频生成")
        }
        if text.contains("video generation") || text.contains("video synthesis") || text.contains("generate video") {
            add("视频生成")
        }
        if text.contains("diffusion") {
            add("扩散模型")
        }
        if text.contains("transformer") {
            add("Transformer 架构")
        }
        if text.contains("temporal") || text.contains("motion consistency") {
            add("时序一致性")
        }
        if text.contains("control") || text.contains("controllable") || text.contains("guidance") {
            add("可控生成")
        }
        if text.contains("personal") || text.contains("custom") || text.contains("preference") {
            add("个性化")
        }
        if text.contains("edit") {
            add("视频编辑")
        }
        if text.contains("benchmark") || text.contains("evaluation") || text.contains("metric") {
            add("评测方法")
        }
        if text.contains("multimodal") || text.contains("vision-language") {
            add("多模态模型")
        }
        if text.contains("eeg") || text.contains("electroencephalography") {
            add("脑电信号")
        }
        if text.contains("music generation") || text.contains("music intervention") || text.contains("musical") {
            add("音乐生成")
        }
        if text.contains("emotion") || text.contains("affective") || text.contains("stress") {
            add("情绪状态")
        }

        return Array(concepts.prefix(4))
    }

    private func paperLimitation(_ summary: String?) -> String {
        guard let summary else { return "" }
        let text = summary.lowercased()
        if text.contains("challenge") || text.contains("challenging") || text.contains("limitation") || text.contains("scarcity") || text.contains("fail") || text.contains("not reliably") {
            return "摘要里也出现了挑战或限制，这部分尤其适合用来提醒你不要把方案说得过满。"
        }
        if text.contains("evaluation") || text.contains("experiment") || text.contains("benchmark") {
            return "摘要中包含实验或评测线索，适合转化成你项目的验收标准。"
        }
        return ""
    }

    private func usageSuggestion(stageOrder: Int) -> String {
        switch stageOrder {
        case 1:
            return "提取论文中的用户问题、研究对象和场景，用来校准你的痛点描述。"
        case 2:
            return "对照论文里的已有方案，写清你的差异化价值来自哪里。"
        case 3:
            return "把论文中的限制、失败条件或伦理提醒转成你的项目边界。"
        case 4:
            return "参考论文中的交互机制，把概念拆成用户可理解的流程。"
        case 5:
            return "借用论文中的用户分类或行为模式，补强你的用户画像。"
        case 6:
            return "把论文中的评价方法改写成你项目可执行的验收标准。"
        case 7:
            return "检查论文中的技术路径和限制，判断你的方案是否可行。"
        case 8:
            return "提取论文里的风险与未知假设，加入你的风险预案。"
        case 9:
            return "引用论文支持你的反思总结，并说明下一轮迭代依据。"
        default:
            return "把论文作为外部证据，补充到你的设计判断中。"
        }
    }

    private func isRelevantPaper(title: String, summary: String?, topicTerms: [String]) -> Bool {
        let text = "\(title) \(summary ?? "")".lowercased()

        if topicTerms.contains("video") {
            let videoTerms = [
                "video", "text-to-video", "text to video", "frame", "scene",
                "long-form", "soundtrack", "temporal", "motion", "visual"
            ]
            guard videoTerms.contains(where: { text.contains($0) }) else {
                return false
            }
        }

        if topicTerms.contains("eeg") {
            guard text.contains("eeg") || text.contains("electroencephalography") || text.contains("brain-computer") else {
                return false
            }
        }

        if topicTerms.contains("music") {
            guard text.contains("music") || text.contains("audio") || text.contains("sound") || text.contains("sonification") else {
                return false
            }
        }

        return true
    }
}

private struct ArxivPaper {
    let id: String
    let title: String
    let summary: String
    let link: String
    let year: Int?
}

private final class ArxivFeedParser: NSObject, XMLParserDelegate {
    private var papers: [ArxivPaper] = []
    private var currentElement = ""
    private var insideEntry = false
    private var currentID = ""
    private var currentTitle = ""
    private var currentSummary = ""
    private var currentLink = ""
    private var currentPublished = ""

    func parse(data: Data) -> [ArxivPaper] {
        papers = []
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return papers
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        if elementName == "entry" {
            insideEntry = true
            currentID = ""
            currentTitle = ""
            currentSummary = ""
            currentLink = ""
            currentPublished = ""
        }
        if insideEntry, elementName == "link", currentLink.isEmpty {
            if let href = attributeDict["href"], attributeDict["rel"] == "alternate" {
                currentLink = href
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard insideEntry else { return }
        switch currentElement {
        case "id":
            currentID += string
        case "title":
            currentTitle += string
        case "summary":
            currentSummary += string
        case "published", "updated":
            currentPublished += string
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "entry" {
            let id = currentID.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = normalize(currentTitle)
            let summary = normalize(currentSummary)
            let link = currentLink.isEmpty ? id : currentLink
            let year = Int(currentPublished.prefix(4))
            if !id.isEmpty, !title.isEmpty {
                papers.append(ArxivPaper(id: id, title: title, summary: summary, link: link, year: year))
            }
            insideEntry = false
        }
        currentElement = ""
    }

    private func normalize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
