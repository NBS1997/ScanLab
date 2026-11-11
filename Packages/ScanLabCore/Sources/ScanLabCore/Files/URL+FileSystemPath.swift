import Foundation

extension URL {
    /// The location as plain text for `FileManager` calls that take a path string.
    ///
    /// Do not use `path()` for this. It escapes the text for use in a web address, so a
    /// space becomes "%20". The phone keeps scans in "Library/Application Support",
    /// which has a space, so `path()` names a folder that does not exist and every
    /// "is it there?" check says no. Build 4 showed exactly that: a saved sweep opened as
    /// "This scan could not be found". SwiftLint now refuses `path()`.
    public var fileSystemPath: String { path(percentEncoded: false) }
}
