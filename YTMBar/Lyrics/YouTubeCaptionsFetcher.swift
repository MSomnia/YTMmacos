import Foundation

struct YouTubeCaptionsFetcher {
    func fetch(videoId: String, language: String = "en") async -> [LyricLine]? {
        guard !videoId.isEmpty,
              let url = URL(string: "https://www.youtube.com/api/timedtext?v=\(videoId)&lang=\(language)&fmt=json3")
        else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return parseJSON3(data)
        } catch {
            return nil
        }
    }

    private func parseJSON3(_ data: Data) -> [LyricLine]? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let events = json["events"] as? [[String: Any]]
        else { return nil }

        var lines: [LyricLine] = []
        for event in events {
            guard let startMs = event["tStartMs"] as? Double,
                  let segs = event["segs"] as? [[String: Any]]
            else { continue }

            let text = segs
                .compactMap { $0["utf8"] as? String }
                .joined()
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !text.isEmpty, text != "\n" {
                lines.append(LyricLine(timestamp: startMs / 1000, text: text))
            }
        }
        return lines.isEmpty ? nil : lines
    }
}
