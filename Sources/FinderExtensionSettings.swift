import FinderSync

@MainActor
enum FinderExtensionSettings {
    static func open() {
        FIFinderSyncController.showExtensionManagementInterface()
    }
}
