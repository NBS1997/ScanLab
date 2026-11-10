import Foundation
import ScanLabCore

/// The reference object as shipped inside the app: `reference-object.stl` and
/// `feature-table.json`, copied straight from `reference-object/output/` by the
/// project file, so the app always uses exactly what the script produced (ADR-010).
///
/// Loading and preparing the shape takes a moment, so it is done once, on first use,
/// away from the main thread (an actor runs its work in the background), and kept.
actor BundledReference {
    private let shapeURL: URL?
    private let tableURL: URL?
    private let log: any Logging
    private var prepared: ReferenceSurface?

    init(bundle: Bundle = .main, log: any Logging) {
        shapeURL = bundle.url(forResource: "reference-object", withExtension: "stl")
        tableURL = bundle.url(forResource: "feature-table", withExtension: "json")
        self.log = log
    }

    /// Only the feature table, for the Reference object sheet.
    func table() throws -> FeatureTable {
        if let prepared { return prepared.reference.table }
        do {
            return try FeatureTable.decode(try read(tableURL, name: "feature table"))
        } catch {
            log.error("accuracy", "Feature table not loaded", ["reason": error.localizedDescription])
            throw error
        }
    }

    /// The shape and table, ready for checking scans.
    func surface() throws -> ReferenceSurface {
        if let prepared { return prepared }
        let started = Date()
        do {
            let shape = try read(shapeURL, name: "shape")
            let table = try read(tableURL, name: "feature table")
            let reference = try ReferenceObject.load(stlData: shape, featureTableData: table)
            let surface = try ReferenceSurface(reference)
            prepared = surface
            log.info(
                "accuracy", "Reference object loaded",
                [
                    "faces": String(reference.mesh.faceCount), "features": String(reference.table.features.count),
                    "skippedFeatures": String(reference.table.skippedFeatures),
                    "ms": String(Int(Date().timeIntervalSince(started) * 1000)),
                ])
            return surface
        } catch {
            log.error("accuracy", "Reference object not loaded", ["reason": error.localizedDescription])
            throw error
        }
    }

    private func read(_ url: URL?, name: String) throws -> Data {
        guard let url else { throw ReferenceError.malformedShape("the \(name) is missing from the app") }
        do {
            return try Data(contentsOf: url)
        } catch {
            throw ReferenceError.malformedShape("the \(name) could not be read")
        }
    }
}
