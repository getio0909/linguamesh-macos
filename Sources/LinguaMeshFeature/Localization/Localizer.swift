import Foundation

struct Localizer {
    func text(
        _ key: String,
        fallback: String,
        locale: UILocale,
        arguments: [String] = []
    ) -> String {
        var localized = localizedBundle(for: locale).localizedString(
            forKey: key,
            value: fallback,
            table: "Localizable"
        )
        for (offset, argument) in arguments.enumerated() {
            localized = localized.replacingOccurrences(
                of: "%\(offset + 1)$@",
                with: argument
            )
        }
        return localized
    }

    func presentedError(
        kind: ClientErrorKind,
        locale: UILocale,
        providerName: String
    ) -> PresentedError {
        let message: String
        let recovery: String
        switch kind {
        case .authentication:
            message = text(
                "error.authentication_failed",
                fallback: "Check the credentials for %1$@ and try again.",
                locale: locale,
                arguments: [providerName]
            )
            recovery = "Update the credential in Keychain."
        case .invalidEndpoint:
            message = text(
                "error.invalid_profile",
                fallback: "Enter a provider name, endpoint, and model.",
                locale: locale
            )
            recovery = "Use HTTPS for remote providers or HTTP on a loopback address."
        case .network, .timeout:
            message = text(
                "error.network_unavailable",
                fallback: "The provider could not be reached.",
                locale: locale
            )
            recovery = "Check the endpoint and network, then try again."
        case .modelUnavailable:
            message = text(
                "error.unknown",
                fallback: "Translation failed. Review diagnostics and try again.",
                locale: locale
            )
            recovery = "Choose another configured model."
        case .malformedResponse:
            message = text(
                "error.unknown",
                fallback: "Translation failed. Review diagnostics and try again.",
                locale: locale
            )
            recovery = "Retry or inspect redacted diagnostics."
        case .cancellation:
            message = text(
                "status.cancelled",
                fallback: "Translation cancelled. Partial output was kept.",
                locale: locale
            )
            recovery = "Partial output remains available."
        case .invalidConfiguration:
            message = text(
                "error.invalid_profile",
                fallback: "Enter a provider name, endpoint, and model.",
                locale: locale
            )
            recovery = "Check the endpoint, model, source text, and target locale."
        case .secureStorageUnavailable:
            message = text(
                "error.unknown",
                fallback: "Translation failed. Review diagnostics and try again.",
                locale: locale
            )
            recovery = "Retry after Keychain Services becomes available."
        case .abiIncompatible:
            message = text(
                "error.incompatible_core",
                fallback: "This app requires a compatible LinguaMesh Core library.",
                locale: locale
            )
            recovery = "Install a client build with a compatible core artifact."
        case .protocolIncompatible:
            message = text(
                "error.incompatible_core",
                fallback: "This app requires a compatible LinguaMesh Core library.",
                locale: locale
            )
            recovery = "Install a client build with a compatible core artifact."
        case .eventBufferOverflow:
            message = text(
                "error.unknown",
                fallback: "Translation failed. Review diagnostics and try again.",
                locale: locale
            )
            recovery = "Retry with a smaller request."
        case .internalFailure:
            message = text(
                "error.unknown",
                fallback: "Translation failed. Review diagnostics and try again.",
                locale: locale
            )
            recovery = "Retry or inspect redacted diagnostics."
        }
        return PresentedError(kind: kind, message: message, recoverySuggestion: recovery)
    }

    private func localizedBundle(for locale: UILocale) -> Bundle {
        if let packagedBundle = packagedResourceBundle(),
           let path = packagedBundle.path(forResource: locale.rawValue, ofType: "lproj"),
           let bundle = Bundle(path: path)
        {
            return bundle
        }
        guard let path = Bundle.module.path(forResource: locale.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path)
        else {
            return Bundle.module
        }
        return bundle
    }

    private func packagedResourceBundle() -> Bundle? {
        Bundle.main.urls(forResourcesWithExtension: "bundle", subdirectory: nil)?
            .lazy
            .compactMap(Bundle.init(url:))
            .first { bundle in
                bundle.bundleURL.lastPathComponent.contains("LinguaMeshFeature")
            }
    }
}
