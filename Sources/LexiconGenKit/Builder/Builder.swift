import Foundation

public enum Builder {
    public static func uniqued(_ fullNames: [String]) -> [String] {
        var segments = fullNames.map { $0.split(separator: ".").map(String.init) }

        var result = [String]()
        for i in segments.indices {
            var currentSegs = [String]()
            var segs = segments[i]
            while let seg = segs.popLast() {
                currentSegs.insert(seg, at: 0)

                let current = currentSegs.joined(separator: ".")
                let targets = result.enumerated().filter { $0.element == current }.map(\.offset)
                guard !targets.isEmpty else {
                    break
                }

                for target in targets {
                    var s = segments[target]
                    result[target] = s.popLast()! + result[target]
                    segments[target] = s
                }
            }

            segments[i] = segs
            result.append(currentSegs.joined())
        }

        return result
    }
}
