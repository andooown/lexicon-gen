import ArgumentParser
import Foundation
import LexiconGenKit
import SwiftSyntax
import SwiftSyntaxBuilder

@main
struct LexiconGen: ParsableCommand {
    @Option
    var sourceDirectory: String
    @Option
    var outputFile: String

    func run() throws {
        print("Source Directory = \(sourceDirectory)")
        print("Output File = \(outputFile)")

        let fileURLs = listJSONFiles(in: URL(fileURLWithPath: sourceDirectory, isDirectory: true))

        print("\(fileURLs.count) files found")

        let context = try buildContext(from: fileURLs)

        print("\(context.generateNamespaceDefinitions().count) namespaces found")
        print("\(context.generateDefinitions().count) definitions found")

        print("Generating...")
        let start = Date()
        let generated = try Generator(context: context).generate()
        print("Completed in \(String(format: "%.3f", Date().timeIntervalSince(start))) s")

        let outputFileURL = URL(fileURLWithPath: outputFile)
        try generated.write(to: outputFileURL, atomically: true, encoding: .utf8)
    }
}

private extension LexiconGen {
    func listJSONFiles(in baseDirectory: URL) -> [URL] {
        guard
            let enumerator = FileManager.default.enumerator(
                at: baseDirectory,
                includingPropertiesForKeys: nil
            )
        else {
            return []
        }

        return enumerator.compactMap { $0 as? URL }.filter {
            $0.pathExtension.lowercased() == "json"
        }
    }

    func buildContext(from fileURLs: [URL]) throws -> GeneratorContext {
        let context = GeneratorContext()
        let decoder = JSONDecoder()
        for fileURL in fileURLs {
            let data = try Data(contentsOf: fileURL)
            let lex = try decoder.decode(LexiconDocument<LexiconRelativeReference>.self, from: data)

            context.append(try lex.transformToAbsoluteReferences())
        }

        return context
    }
}
