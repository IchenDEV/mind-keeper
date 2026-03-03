import AppKit
import SwiftUI

struct AppIconProvider {
    static func icon(for bundleId: String?) -> NSImage? {
        guard let bundleId, !bundleId.isEmpty else { return nil }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false))
    }
}

struct AppIconView: View {
    let bundleId: String?
    let size: CGFloat

    var body: some View {
        if let bundleId, let nsImage = AppIconProvider.icon(for: bundleId) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .clipShape(.rect(cornerRadius: size * 0.22))
        } else {
            Image(systemName: "app.fill")
                .font(.system(size: size * 0.65))
                .frame(width: size, height: size)
                .foregroundStyle(.tertiary)
        }
    }
}
