import Foundation

/// Fallbacks for stores that do not keep accuracy reports (such as test stores written
/// before unit U10). Reading finds no report; writing fails loudly rather than
/// pretending to have saved. `FileScanStore` and `MemoryScanStore` provide the real
/// versions.
extension ScanStoring {
    public func reportData(for id: UUID) throws -> Data? {
        nil
    }

    public func replaceReport(_ report: Data, for id: UUID) throws {
        throw StoreError.writeFailed("this storage cannot keep accuracy reports")
    }
}
