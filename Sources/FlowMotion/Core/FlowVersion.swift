// MARK: - FlowMotion version

public extension FlowMotion {
    /// The current semantic version of the FlowMotion library.
    static let version = SemanticVersion(major: 0, minor: 1, patch: 0)

    /// A structured semantic version.
    struct SemanticVersion: Sendable, CustomStringConvertible {
        public let major: Int
        public let minor: Int
        public let patch: Int

        public var description: String { "\(major).\(minor).\(patch)" }

        public init(major: Int, minor: Int, patch: Int) {
            self.major = major
            self.minor = minor
            self.patch = patch
        }
    }
}
