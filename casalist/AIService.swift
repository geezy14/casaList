//
//  AIService.swift
//  casalist
//
//  Three-tier AI router (Apple local FM / Apple PCC / Claude via proxy).
//  CROSS-APP STANDARD — mirrors casaHealth's AIService. See the shared memory
//  `reference_three_tier_aiservice` for the rationale + the one-shared-proxy rule.
//
//  STATUS: BUILT but UNWIRED. Nothing calls this yet. casalist has no AI surfaces
//  today — this is forward-looking scaffolding. Views must NEVER call a model
//  directly — they call `AIService.shared.generate(task:context:)`. The cloud tiers
//  (PCC, Claude) stay dark until provisioned; everything falls back to on-device.
//
//  PORTABILITY: the PCC tier is gated behind `#if AISERVICE_PCC` so this compiles
//  on the iOS 26 SDK (PrivateCloudComputeLanguageModel is iOS-27-SDK-only). Define
//  AISERVICE_PCC in build settings once this app adopts the iOS 27 SDK.
//
//  KEY SAFETY: no Anthropic key in the binary. Claude routes through a shared
//  zero-log backend proxy that holds the single key for ALL of Geezy's apps; this
//  app authenticates with its own proxy token (Keychain), never an Anthropic key.
//

import Foundation
import os
import Security
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Task taxonomy

/// Every distinct AI generation casalist performs. New surface = new case here,
/// not an ad-hoc model call in a view.
enum ListAITask: String, CaseIterable, Sendable {
    case itemParse           // NL entry → structured list item
    case listSummary         // summarize the state of a list
    case weeklyReview        // synthesize the week's list activity
    case patternAnalysis     // deep multi-week done-vs-deferred patterns

    /// The tier this task prefers. Fallback is defined by `AIService.providerChain`.
    var preferredProvider: AIProvider {
        switch self {
        case .itemParse, .listSummary: return .appleLocal
        case .weeklyReview:            return .appleServer
        case .patternAnalysis:         return .claude
        }
    }

    /// System instructions, shared across tiers so the voice is identical.
    var instructions: String {
        let base = """
        You assist inside casalist, a lists + tasks app. Be specific and grounded \
        in the user's own items. Never invent tasks or due dates. Observational, concise.
        """
        switch self {
        case .itemParse:
            return base + "\nParse this entry into a structured list item."
        case .listSummary:
            return base + "\nSummarize the state of this list: what's done, what's stuck."
        case .weeklyReview:
            return base + "\nSynthesize the week's list activity into a short review."
        case .patternAnalysis:
            return base + "\nFind multi-week patterns in what gets done vs deferred."
        }
    }
}

// MARK: - Providers

enum AIProvider: String, Sendable {
    case appleLocal    // Tier 1 — on-device FoundationModels
    case appleServer   // Tier 2 — Private Cloud Compute (gated by AISERVICE_PCC)
    case claude        // Tier 3 — Anthropic via shared backend proxy

    var displayName: String {
        switch self {
        case .appleLocal:  return "Apple (on-device)"
        case .appleServer: return "Apple PCC (cloud)"
        case .claude:      return "Claude"
        }
    }
}

// MARK: - Errors

enum AIServiceError: LocalizedError {
    case noProviderAvailable(ListAITask)
    case allProvidersFailed(ListAITask, underlying: Error?)

    var errorDescription: String? {
        switch self {
        case .noProviderAvailable(let t): return "No AI provider available for \(t.rawValue)."
        case .allProvidersFailed(let t, let e):
            return "All AI providers failed for \(t.rawValue): \(e.map { "\($0)" } ?? "unknown")."
        }
    }
}

// MARK: - Service

/// The single AI entry point. Stateless + thread-safe. Call from a view model, not a view.
final class AIService: Sendable {
    static let shared = AIService()
    private init() {}
    private let log = Logger(subsystem: "com.gbrown10.casalist", category: "AIService")

    /// Generate text for `task` given an already-grounded `context` string. Walks the
    /// provider chain, skipping unavailable tiers and stepping down on error.
    func generate(_ task: ListAITask, context: String) async throws -> String {
        let chain = AIService.providerChain(for: task)
        var lastError: Error?
        var anyAvailable = false
        for provider in chain {
            guard await isAvailable(provider) else { continue }
            anyAvailable = true
            do {
                let out = try await run(task, context: context, on: provider)
                if provider != task.preferredProvider {
                    log.notice("\(task.rawValue, privacy: .public) fell back to \(provider.rawValue, privacy: .public)")
                }
                return out
            } catch {
                lastError = error
                log.error("\(task.rawValue, privacy: .public) \(provider.rawValue, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
                continue
            }
        }
        if !anyAvailable { throw AIServiceError.noProviderAvailable(task) }
        throw AIServiceError.allProvidersFailed(task, underlying: lastError)
    }

    /// Preferred provider first, then graceful step-downs. On-device is always the floor.
    static func providerChain(for task: ListAITask) -> [AIProvider] {
        switch task.preferredProvider {
        case .appleLocal:  return [.appleLocal]
        case .appleServer: return [.appleServer, .appleLocal]
        case .claude:      return [.claude, .appleServer, .appleLocal]
        }
    }

    private func isAvailable(_ provider: AIProvider) async -> Bool {
        switch provider {
        case .appleLocal:
            #if canImport(FoundationModels)
            if #available(iOS 26.0, *) {
                if case .available = SystemLanguageModel.default.availability { return true }
            }
            #endif
            return false
        case .appleServer:
            #if AISERVICE_PCC
            if #available(iOS 27.0, *) { return PCCBridge.isAvailable }
            #endif
            return false
        case .claude:
            return ClaudeProvider.isReady
        }
    }

    private func run(_ task: ListAITask, context: String, on provider: AIProvider) async throws -> String {
        switch provider {
        case .appleLocal:
            #if canImport(FoundationModels)
            if #available(iOS 26.0, *) {
                let session = LanguageModelSession(instructions: task.instructions)
                return try await session.respond(to: context).content
            }
            #endif
            throw AIServiceError.noProviderAvailable(task)
        case .appleServer:
            #if AISERVICE_PCC
            if #available(iOS 27.0, *) {
                return try await PCCBridge.respond(instructions: task.instructions, context: context)
            }
            #endif
            throw AIServiceError.noProviderAvailable(task)
        case .claude:
            return try await ClaudeProvider.generate(system: task.instructions, user: context)
        }
    }
}

// MARK: - PCC bridge (iOS 27 SDK only — compiled only under AISERVICE_PCC)

#if AISERVICE_PCC
@available(iOS 27.0, *)
enum PCCBridge {
    /// Opt-in flag — off by default so PCC stays dark until explicitly enabled.
    static var enabled: Bool { UserDefaults.standard.bool(forKey: "ai.pcc.enabled") }
    static var isAvailable: Bool {
        guard enabled else { return false }
        let pcc = PrivateCloudComputeLanguageModel()
        guard case .available = pcc.availability else { return false }
        return true
    }
    static func respond(instructions: String, context: String) async throws -> String {
        let session = LanguageModelSession(model: PrivateCloudComputeLanguageModel(),
                                           instructions: instructions)
        return try await session.respond(to: context).content
    }
}
#endif

// MARK: - Claude provider (key-safe, shared proxy)

/// Routes Claude through the shared zero-log proxy. No Anthropic key in the binary.
enum ClaudeProvider {
    static var isReady: Bool { ClaudeProxyConfig.current.isReady }

    static func generate(system: String, user: String) async throws -> String {
        let client = ClaudeProxyClient(config: ClaudeProxyConfig.current)
        return try await client.respond(system: system, user: user)
    }
}

/// Endpoint + per-app proxy token. The token authenticates THIS app to the shared
/// proxy; it is NOT an Anthropic key. Off (isReady == false) until configured.
struct ClaudeProxyConfig {
    var enabled: Bool
    var endpoint: String      // shared zero-log proxy base URL (Anthropic-shaped)
    var proxyToken: String    // this app's token for the proxy (Keychain)
    var model: String

    static let tokenKeychainAccount = "ai.claude.proxyToken"

    static var current: ClaudeProxyConfig {
        let d = UserDefaults.standard
        return .init(
            enabled: d.bool(forKey: "ai.claude.enabled"),
            endpoint: d.string(forKey: "ai.claude.endpoint") ?? "",
            proxyToken: AIServiceKeychain.string(forKey: tokenKeychainAccount) ?? "",
            model: d.string(forKey: "ai.claude.model") ?? "claude-sonnet-4-6"
        )
    }
    var isReady: Bool { enabled && !endpoint.isEmpty && !proxyToken.isEmpty }
}

enum ClaudeProxyError: Error { case notConfigured, http(Int), empty, decode }

/// Anthropic Messages-shaped client pointed at the shared proxy. Any failure throws
/// so AIService falls back to a lower tier.
struct ClaudeProxyClient {
    let config: ClaudeProxyConfig
    func respond(system: String, user: String) async throws -> String {
        guard config.isReady else { throw ClaudeProxyError.notConfigured }
        let base = config.endpoint.hasSuffix("/v1/messages") ? config.endpoint
                 : (config.endpoint.hasSuffix("/") ? String(config.endpoint.dropLast()) : config.endpoint) + "/v1/messages"
        guard let url = URL(string: base) else { throw ClaudeProxyError.notConfigured }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 20
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(config.proxyToken, forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "model": config.model,
            "max_tokens": 400,
            "system": system,
            "messages": [["role": "user", "content": user]]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw ClaudeProxyError.empty }
        guard (200..<300).contains(http.statusCode) else { throw ClaudeProxyError.http(http.statusCode) }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = obj["content"] as? [[String: Any]],
              let text = content.first(where: { ($0["type"] as? String) == "text" })?["text"] as? String,
              !text.isEmpty else { throw ClaudeProxyError.decode }
        return text
    }
}

/// Minimal Keychain wrapper for the proxy token (never UserDefaults).
enum AIServiceKeychain {
    static func string(forKey key: String) -> String? {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data, let s = String(data: data, encoding: .utf8) else { return nil }
        return s
    }
    static func set(_ value: String, forKey key: String) {
        delete(forKey: key)
        guard !value.isEmpty, let data = value.data(using: .utf8) else { return }
        SecItemAdd([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ] as CFDictionary, nil)
    }
    static func delete(forKey key: String) {
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ] as CFDictionary)
    }
}
