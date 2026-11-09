import Foundation

enum AppConstants {
    static let appGroupID = "group.app.olo.vpn"
    static let tunnelBundleID = "app.olo.vpn.PacketTunnel"
    static let tunnelProviderDescription = "Olo"
    static let configFileName = "olo-config.json"
    static let optionsConfigKey = "ConfigContent"
    static let optionsProtectionKey = "ProtectionJSON"
    static let clashAPIURL = URL(string: "http://127.0.0.1:9090")!
    static let clashSecret = "olo-local"
}
