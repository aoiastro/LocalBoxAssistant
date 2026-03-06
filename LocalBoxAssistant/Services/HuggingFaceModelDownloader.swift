import Foundation

struct HFModelConfig {
    let repoID: String
    let revision: String
    let files: [String]?
    let token: String?

    static let `default` = HFModelConfig(
        repoID: "mlx-community/Qwen2.5-1.5B-Instruct-4bit",
        revision: "main",
        files: nil,
        token: nil
    )
}

private struct HFRepoEntry: Decodable {
    let path: String
    let type: String
}

actor HuggingFaceModelDownloader {
    private let session: URLSession = .shared
    private let fileManager = FileManager.default

    func ensureModelDownloaded(config: HFModelConfig) async throws -> URL {
        let rootDirectory = try appModelsDirectory()
        let modelDirectory = rootDirectory.appendingPathComponent(safeModelDirectoryName(config.repoID), isDirectory: true)
        try fileManager.createDirectory(at: modelDirectory, withIntermediateDirectories: true)

        let marker = modelDirectory.appendingPathComponent(".download-complete", isDirectory: false)
        if fileManager.fileExists(atPath: marker.path) {
            return modelDirectory
        }

        let filesToDownload = try await resolveFiles(config: config)
        for file in filesToDownload {
            try await downloadFile(
                repoID: config.repoID,
                revision: config.revision,
                token: config.token,
                remotePath: file,
                into: modelDirectory
            )
        }

        let stamp = "ok:\(Date().timeIntervalSince1970)\n"
        guard let stampData = stamp.data(using: .utf8) else {
            throw LocalLLMError.modelDownloadFailed("Marker serialization failed")
        }
        try stampData.write(to: marker, options: .atomic)
        return modelDirectory
    }

    private func resolveFiles(config: HFModelConfig) async throws -> [String] {
        if let files = config.files, !files.isEmpty {
            return files
        }

        let manifestURL = URL(string: "https://huggingface.co/api/models/\(config.repoID)/tree/\(config.revision)?recursive=1")!
        var request = URLRequest(url: manifestURL)
        request.httpMethod = "GET"
        if let token = config.token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw LocalLLMError.modelDownloadFailed("HF manifest fetch failed")
        }

        let entries = try JSONDecoder().decode([HFRepoEntry].self, from: data)
        let files = entries
            .filter { $0.type == "file" }
            .map(\.path)
            .filter(shouldInclude(path:))
            .sorted()

        guard !files.isEmpty else {
            throw LocalLLMError.modelDownloadFailed("No downloadable model files found")
        }
        return files
    }

    private func shouldInclude(path: String) -> Bool {
        let fileName = URL(fileURLWithPath: path).lastPathComponent
        let keepByName: Set<String> = [
            "config.json",
            "generation_config.json",
            "tokenizer.json",
            "tokenizer_config.json",
            "special_tokens_map.json",
            "model.safetensors.index.json",
            "merges.txt",
            "vocab.json",
            "tokenizer.model",
            "sentencepiece.bpe.model",
            "chat_template.json"
        ]
        if keepByName.contains(fileName) {
            return true
        }
        if fileName.hasSuffix(".safetensors") || fileName.hasSuffix(".tiktoken") {
            return true
        }
        return false
    }

    private func downloadFile(
        repoID: String,
        revision: String,
        token: String?,
        remotePath: String,
        into modelDirectory: URL
    ) async throws {
        let destination = modelDirectory.appendingPathComponent(remotePath, isDirectory: false)
        if fileManager.fileExists(atPath: destination.path) {
            return
        }

        try fileManager.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encodedRemotePath = remotePath
            .split(separator: "/")
            .map { String($0).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }
            .joined(separator: "/")

        let url = URL(string: "https://huggingface.co/\(repoID)/resolve/\(revision)/\(encodedRemotePath)?download=true")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let token = token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (tempURL, response) = try await session.download(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw LocalLLMError.modelDownloadFailed("Failed downloading \(remotePath)")
        }

        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.moveItem(at: tempURL, to: destination)
    }

    private func appModelsDirectory() throws -> URL {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw LocalLLMError.modelDownloadFailed("Application Support directory unavailable")
        }
        let modelsDirectory = appSupport.appendingPathComponent("Models", isDirectory: true)
        try fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        return modelsDirectory
    }

    private func safeModelDirectoryName(_ repoID: String) -> String {
        repoID.replacingOccurrences(of: "/", with: "--")
    }
}
