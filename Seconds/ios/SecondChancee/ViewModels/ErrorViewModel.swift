import SwiftUI

@Observable
class ErrorViewModel {
    var currentError: AppError?
    var isShowingError = false
    
    static let shared = ErrorViewModel()
    
    private init() {}
    
    func showError(_ error: Error, file: String = #file, function: String = #function, line: Int = #line) {
        if Self.shouldSuppressGlobalModal(for: error) {
            return
        }
        let appError = AppError(
            underlyingError: error,
            file: file,
            function: function,
            line: line
        )
        currentError = appError
        isShowingError = true
    }

    /// Avoids full-screen technical modals for RevenueCat / StoreKit subscription noise (handled inline on the paywall).
    private static func shouldSuppressGlobalModal(for error: Error) -> Bool {
        let combined = error.localizedDescription + String(describing: error)
        let lower = combined.lowercased()
        if lower.contains("rev.cat") { return true }
        if lower.contains("none of the products registered") { return true }
        if lower.contains("offerings-empty") { return true }
        if lower.contains("configuration") && lower.contains("revenuecat") { return true }
        if lower.contains("skerrordomain") && lower.contains("payment cancelled") { return true }
        return false
    }
    
    func showError(message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let appError = AppError(
            message: message,
            file: file,
            function: function,
            line: line
        )
        currentError = appError
        isShowingError = true
    }
    
    func dismissError() {
        isShowingError = false
        currentError = nil
    }
}

struct AppError: Identifiable {
    let id = UUID()
    let message: String
    let detailedDescription: String
    let file: String
    let function: String
    let line: Int
    let timestamp: Date
    
    init(underlyingError: Error, file: String, function: String, line: Int) {
        self.message = underlyingError.localizedDescription
        var details = String(describing: underlyingError)
        let ns = underlyingError as NSError
        details += "\nDomain: \(ns.domain)  Code: \(ns.code)"
        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? Error {
            details += "\nUnderlying: \(underlying.localizedDescription)"
        }
        self.detailedDescription = details
        self.file = (file as NSString).lastPathComponent
        self.function = function
        self.line = line
        self.timestamp = Date()
    }
    
    init(message: String, file: String, function: String, line: Int) {
        self.message = message
        self.detailedDescription = message
        self.file = (file as NSString).lastPathComponent
        self.function = function
        self.line = line
        self.timestamp = Date()
    }
    
    var locationString: String {
        "\(file):\(line) in \(function)"
    }
    
    var timestampString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}
