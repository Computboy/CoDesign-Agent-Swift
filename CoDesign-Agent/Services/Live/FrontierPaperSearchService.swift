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
        return decoded.data
            .filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .prefix(limit)
            .map { paper in
                ResourceCard(
                    id: "semantic-scholar-\(paper.paperId)",
                    title: paper.title,
                    type: .paper,
                    relatedStages: [stageOrder],
                    tags: ["前沿论文", "研究", "证据"],
                    summary: summarize(paper.abstract),
                    whyRelevant: "这篇论文由联网检索返回，可作为当前阶段的外部研究证据。",
                    howToUse: usageSuggestion(stageOrder: stageOrder),
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
        return parser.parse(data: data)
            .prefix(limit)
            .map { paper in
                ResourceCard(
                    id: "arxiv-\(paper.id)",
                    title: paper.title,
                    type: .paper,
                    relatedStages: [stageOrder],
                    tags: ["前沿论文", "arXiv", "研究", "证据"],
                    summary: summarize(paper.summary),
                    whyRelevant: "这是 arXiv 最新提交中与当前阶段相关的联网论文，可作为前沿研究线索。",
                    howToUse: usageSuggestion(stageOrder: stageOrder),
                    sourceURL: URL(string: paper.link),
                    year: paper.year,
                    venue: "arXiv"
                )
            }
    }

    private func buildQuery(stageOrder: Int, brief: DesignBrief?, recentMessage: String?) -> String {
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
        let raw = buildQuery(stageOrder: stageOrder, brief: brief, recentMessage: recentMessage)
        let words = raw
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 }
            .prefix(8)

        let query = words.map { "all:\($0)" }.joined(separator: " OR ")
        return query.isEmpty ? "all:human OR all:AI OR all:design" : query
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
