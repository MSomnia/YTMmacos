import Foundation

struct LRCLIBFetcher {

    func fetch(title: String, artist: String) async -> [LyricLine]? {
        var components = URLComponents(string: "https://lrclib.net/api/search")!
        components.queryItems = [
            URLQueryItem(name: "track_name",  value: title),
            URLQueryItem(name: "artist_name", value: artist)
        ]
        guard let url = components.url else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }

            guard let results = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let hit = results.first(where: { ($0["syncedLyrics"] as? String)?.isEmpty == false }),
                  let lrc = hit["syncedLyrics"] as? String
            else { return nil }

            return parseLRC(lrc)
        } catch {
            return nil
        }
    }

    // MARK: - LRC Parser

    private func parseLRC(_ lrc: String) -> [LyricLine]? {
        // Matches [mm:ss.xx] or [mm:ss.xxx]
        guard let regex = try? NSRegularExpression(
            pattern: #"\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)"#
        ) else { return nil }

        var lines: [LyricLine] = []

        for raw in lrc.components(separatedBy: "\n") {
            guard let m = regex.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)),
                  m.numberOfRanges == 5,
                  let r1 = Range(m.range(at: 1), in: raw),
                  let r2 = Range(m.range(at: 2), in: raw),
                  let r3 = Range(m.range(at: 3), in: raw),
                  let r4 = Range(m.range(at: 4), in: raw)
            else { continue }

            let mins  = Double(raw[r1]) ?? 0
            let secs  = Double(raw[r2]) ?? 0
            let frac  = Double(raw[r3]) ?? 0
            let div   = raw[r3].count == 3 ? 1000.0 : 100.0
            let timestamp = mins * 60 + secs + frac / div
            let text  = raw[r4].trimmingCharacters(in: .whitespaces)

            if !text.isEmpty {
                lines.append(LyricLine(timestamp: timestamp, text: text))
            }
        }
        return lines.isEmpty ? nil : lines
    }
}
