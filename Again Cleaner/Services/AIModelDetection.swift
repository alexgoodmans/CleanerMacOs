//
//  AIModelDetection.swift
//  Again Cleaner
//
//  Heuristics for local machine-learning weights. These are NOT cache.
//

import Foundation

enum AIModelDetection {

    nonisolated static let fileExtensions: Set<String> = [
        "mlpackage", "mlmodel", "mlmodelc",
        "safetensors", "gguf", "ggml", "pt", "pth", "onnx",
        "ckpt", "tflite",
    ]

    nonisolated static let directoryNames: Set<String> = [
        "models", "model", "checkpoints", "weights", "loras",
        "huggingface", "ollama", "comfyui",
        "optguideondevicemodel",
    ]

    nonisolated static func isModelFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        let name = url.lastPathComponent.lowercased()
        if fileExtensions.contains(ext) { return true }
        if name.hasSuffix(".safetensors") || name.hasSuffix(".gguf") { return true }
        if ext == "bin" {
            return name.contains("model") || name.contains("weight")
                || name.contains("pytorch") || name.contains("flux")
        }
        return false
    }

    /// A folder looks like a model store when its name matches, or it contains
    /// known weight files (checked via `childNames`, not a recursive walk).
    nonisolated static func isModelDirectory(name: String, childNames: [String]) -> Bool {
        let n = name.lowercased()
        if directoryNames.contains(n) { return true }
        if n.contains("ondevicemodel") || n.hasSuffix("modelcatalog") { return true }
        if n.contains("flux") || n.contains("stable-diffusion") || n.contains("whisper") {
            return true
        }
        let lowerChildren = childNames.map { $0.lowercased() }
        return lowerChildren.contains { child in
            let url = URL(fileURLWithPath: child)
            return isModelFile(url)
        }
    }

    nonisolated static func explanation(app: String?, modelName: String) -> (why: String, consequence: String) {
        let owner = app ?? String(localized: "an application")
        return (
            String(localized: "This is a downloaded local AI model (\(modelName)). It is not cache. Removing it frees disk space, but \(owner) may need to download it again."),
            String(localized: "The application will re-download the model the next time it needs it — or fail until you restore it.")
        )
    }
}
