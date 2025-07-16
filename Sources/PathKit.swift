// PathKit - Modern cross-platform path operations with Swift 6 support

import Foundation

// MARK: - Core Path Type

/// Represents a filesystem path with modern Swift concurrency support
public struct Path: Sendable {
    /// The character used by the OS to separate two path elements
    public static let separator = "/"

    /// The underlying URL representation (thread-safe)
    internal let url: URL
    
    /// Thread-safe file system info provider
    internal let fileSystemInfo: any FileSystemInfo
    
    // MARK: - Initialization
    
    public init() {
        self.init("")
    }
    
    /// Create a Path from a given String
    public init(_ path: String) {
        self.init(path, fileSystemInfo: DefaultFileSystemInfo())
    }
    
    internal init(_ path: String, fileSystemInfo: any FileSystemInfo) {
        // Expand tilde for user paths
        let expandedPath = path.hasPrefix("~") ? 
            (path as NSString).expandingTildeInPath : path
        
        self.url = URL(fileURLWithPath: expandedPath)
        self.fileSystemInfo = fileSystemInfo
    }
    
    internal init(fileSystemInfo: any FileSystemInfo) {
        self.init("", fileSystemInfo: fileSystemInfo)
    }
    
    /// Create a Path by joining multiple path components together
    public init<S: Collection>(components: S) where S.Element == String {
        let path = components.joined(separator: "/")
        self.init(path)
    }
    
    // MARK: - Properties
    
    /// String representation of the path
    public var string: String {
        url.path
    }
    
    /// Path components
    public var components: [String] {
        url.pathComponents
    }
    
    /// The last path component
    public var lastComponent: String {
        url.lastPathComponent
    }
    
    /// The last path component without its extension
    public var lastComponentWithoutExtension: String {
        url.deletingPathExtension().lastPathComponent
    }
    
    /// Returns the path extension
    public var `extension`: String {
        url.pathExtension
    }
    
    /// Returns the parent directory
    public var parent: Path {
        Path(url.deletingLastPathComponent().path, fileSystemInfo: fileSystemInfo)
    }
    
    // MARK: - Path Operations
    
    /// Returns absolute path
    public func absolute() -> Path {
        if url.path.hasPrefix("/") {
            return self
        }
        let absoluteURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(url.path)
        return Path(absoluteURL.path, fileSystemInfo: fileSystemInfo)
    }
    
    /// Returns if the path is absolute
    public var isAbsolute: Bool {
        url.path.hasPrefix("/")
    }
    
    /// Returns if the path is relative
    public var isRelative: Bool {
        !isAbsolute
    }
    
    /// Normalize the path by removing redundant components
    public func normalize() -> Path {
        Path(url.standardized.path, fileSystemInfo: fileSystemInfo)
    }
    
    /// Abbreviate path by replacing home directory with ~
    public func abbreviate() -> Path {
        let homePath = (NSHomeDirectory() as NSString).appendingPathComponent("")
        if url.path.hasPrefix(homePath) {
            let relativePath = String(url.path.dropFirst(homePath.count - 1))
            return Path("~" + relativePath, fileSystemInfo: fileSystemInfo)
        }
        return self
    }
    
    // MARK: - File System Queries (Thread-safe)
    
    /// Returns if the path exists
    public var exists: Bool {
        fileSystemInfo.exists(self)
    }
    
    /// Returns if the path is a directory
    public var isDirectory: Bool {
        fileSystemInfo.isDirectory(self)
    }
    
    /// Returns if the path is a regular file
    public var isFile: Bool {
        fileSystemInfo.isFile(self)
    }
    
    /// Returns if the path is a symbolic link
    public var isSymlink: Bool {
        fileSystemInfo.isSymlink(self)
    }
    
    /// Returns if the path is readable
    public var isReadable: Bool {
        fileSystemInfo.isReadable(self)
    }
    
    /// Returns if the path is writable
    public var isWritable: Bool {
        fileSystemInfo.isWritable(self)
    }
    
    /// Returns if the path is executable
    public var isExecutable: Bool {
        fileSystemInfo.isExecutable(self)
    }
    
    /// Returns if the path is deletable
    public var isDeletable: Bool {
        fileSystemInfo.isDeletable(self)
    }
    
    // MARK: - Path Building
    
    /// Append a path component
    public func appending(_ component: String) -> Path {
        Path(url.appendingPathComponent(component).path, fileSystemInfo: fileSystemInfo)
    }
    
    /// Append a path extension
    public func appendingExtension(_ ext: String) -> Path {
        Path(url.appendingPathExtension(ext).path, fileSystemInfo: fileSystemInfo)
    }
    
    // MARK: - Directory Operations
    
    /// Returns the current working directory
    public static func current() -> Path {
        Path(FileManager.default.currentDirectoryPath)
    }
    
    /// Change current working directory
    @discardableResult
    public static func chdir(_ path: Path) throws -> Path {
        let previousPath = current()
        guard FileManager.default.changeCurrentDirectoryPath(path.string) else {
            throw PathError.changeDirectoryFail(path: path)
        }
        return previousPath
    }
    
    /// Change current working directory and execute closure
    public static func chdir<T>(_ path: Path, closure: () throws -> T) rethrows -> T {
        let previous = try! chdir(path)
        defer { try! chdir(previous) }
        return try closure()
    }
    
    /// Returns the home directory
    public static func home() -> Path {
        Path(NSHomeDirectory())
    }
    
    /// Returns the temporary directory
    public static func temporary() -> Path {
        Path(NSTemporaryDirectory())
    }
    
    // MARK: - File Operations (Thread-safe)
    
    /// Read file contents as Data
    public func read() throws -> Data {
        try Data(contentsOf: url)
    }
    
    /// Read file contents as String
    public func read(_ encoding: String.Encoding = .utf8) throws -> String {
        try String(contentsOf: url, encoding: encoding)
    }
    
    /// Write data to file
    public func write(_ data: Data) throws {
        try data.write(to: url)
    }
    
    /// Write string to file
    public func write(_ string: String, encoding: String.Encoding = .utf8) throws {
        try string.write(to: url, atomically: true, encoding: encoding)
    }
    
    /// Delete the file or directory
    public func delete() throws {
        try FileManager.default.removeItem(at: url)
    }
    
    /// Move file to another location
    @discardableResult
    public func move(_ destination: Path) throws -> Path {
        try FileManager.default.moveItem(at: url, to: destination.url)
        return destination
    }
    
    /// Copy file to another location
    @discardableResult
    public func copy(_ destination: Path) throws -> Path {
        try FileManager.default.copyItem(at: url, to: destination.url)
        return destination
    }
    
    /// Create directory
    public func mkdir() throws -> Path {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        return self
    }
    
    /// Create directory with intermediate directories
    public func mkpath() throws -> Path {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return self
    }
    
    /// Create symbolic link
    public func symlink(_ destination: Path) throws {
        try FileManager.default.createSymbolicLink(at: url, withDestinationURL: destination.url)
    }
    
    // MARK: - Directory Enumeration
    
    /// Returns directory contents
    public func children() throws -> [Path] {
        let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        return contents.map { Path($0.path, fileSystemInfo: fileSystemInfo) }
    }
    
    /// Returns all files recursively
    public func recursiveChildren() throws -> [Path] {
        let paths = try FileManager.default.subpathsOfDirectory(atPath: url.path)
        return paths.map { self.appending($0) }
    }
    
    // MARK: - Glob Operations (Cross-platform)
    
    /// Glob for files matching pattern (static method)
    public static func glob(_ pattern: String) -> [Path] {
        let engine = GlobEngineFactory.makeEngine()
        let results = engine.glob(pattern)
        return results.map { Path($0) }
    }
    
    /// Glob for files relative to this path
    public func glob(_ pattern: String) -> [Path] {
        let fullPattern = appending(pattern).string
        return Path.glob(fullPattern)
    }
    
    // MARK: - Pattern Matching
    
    /// Check if path matches a glob pattern
    public func match(_ pattern: String) -> Bool {
        guard let cPattern = strdup(pattern),
              let cPath = strdup(string) else {
            return false
        }
        defer {
            free(cPattern)
            free(cPath)
        }
        return fnmatch(cPattern, cPath, 0) == 0
    }
}

// MARK: - Conformances

extension Path: Equatable {
    public static func == (lhs: Path, rhs: Path) -> Bool {
        lhs.url == rhs.url
    }
}

extension Path: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
}

extension Path: Comparable {
    public static func < (lhs: Path, rhs: Path) -> Bool {
        lhs.string < rhs.string
    }
}

extension Path: CustomStringConvertible {
    public var description: String {
        string
    }
}

extension Path: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(value)
    }
}

extension Path: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let path = try container.decode(String.self)
        self.init(path)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(string)
    }
}

// MARK: - Operators

extension Path {
    /// Append path component using + operator
    public static func + (lhs: Path, rhs: String) -> Path {
        lhs.appending(rhs)
    }
    
    /// Append another path
    public static func + (lhs: Path, rhs: Path) -> Path {
        lhs.appending(rhs.string)
    }
}

// MARK: - Sequence Support

extension Path: Sequence {
    public func makeIterator() -> PathIterator {
        PathIterator(path: self)
    }
}

public struct PathIterator: IteratorProtocol {
    private let path: Path
    private var index = 0
    
    init(path: Path) {
        self.path = path
    }
    
    public mutating func next() -> Path? {
        guard index < path.components.count else { return nil }
        defer { index += 1 }
        
        let component = path.components[index]
        return component == "/" ? Path("/") : Path(component)
    }
}

// MARK: - Directory Enumeration Options

extension Path {
    public struct DirectoryEnumerationOptions: OptionSet, Sendable {
        public let rawValue: UInt
        
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }
        
        public static let skipsSubdirectoryDescendants = DirectoryEnumerationOptions(rawValue: FileManager.DirectoryEnumerationOptions.skipsSubdirectoryDescendants.rawValue)
        public static let skipsPackageDescendants = DirectoryEnumerationOptions(rawValue: FileManager.DirectoryEnumerationOptions.skipsPackageDescendants.rawValue)
        public static let skipsHiddenFiles = DirectoryEnumerationOptions(rawValue: FileManager.DirectoryEnumerationOptions.skipsHiddenFiles.rawValue)
    }
    
    /// Enumerates directory with options
    public func iterateChildren(options: DirectoryEnumerationOptions = []) -> PathDirectoryEnumerator {
        PathDirectoryEnumerator(path: self, options: options)
    }
}

public struct PathDirectoryEnumerator: Sequence, IteratorProtocol {
    private let enumerator: FileManager.DirectoryEnumerator?
    private let basePath: Path
    
    init(path: Path, options: Path.DirectoryEnumerationOptions) {
        self.basePath = path
        let fileManagerOptions = FileManager.DirectoryEnumerationOptions(rawValue: options.rawValue)
        self.enumerator = FileManager.default.enumerator(
            at: path.url,
            includingPropertiesForKeys: nil,
            options: fileManagerOptions
        )
    }
    
    public mutating func next() -> Path? {
        guard let url = enumerator?.nextObject() as? URL else { return nil }
        return Path(url.path, fileSystemInfo: basePath.fileSystemInfo)
    }
}

// MARK: - Errors

public enum PathError: Error, CustomStringConvertible {
    case changeDirectoryFail(path: Path)
    
    public var description: String {
        switch self {
        case .changeDirectoryFail(let path):
            return "Failed to change directory to: \(path)"
        }
    }
}

// MARK: - FileSystemInfo Protocol (Thread-safe)

internal protocol FileSystemInfo: Sendable {
    func exists(_ path: Path) -> Bool
    func isDirectory(_ path: Path) -> Bool
    func isFile(_ path: Path) -> Bool
    func isSymlink(_ path: Path) -> Bool
    func isReadable(_ path: Path) -> Bool
    func isWritable(_ path: Path) -> Bool
    func isExecutable(_ path: Path) -> Bool
    func isDeletable(_ path: Path) -> Bool
}

internal struct DefaultFileSystemInfo: FileSystemInfo {
    func exists(_ path: Path) -> Bool {
        FileManager.default.fileExists(atPath: path.string)
    }
    
    func isDirectory(_ path: Path) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: path.string, isDirectory: &isDir) && isDir.boolValue
    }
    
    func isFile(_ path: Path) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: path.string, isDirectory: &isDir) && !isDir.boolValue
    }
    
    func isSymlink(_ path: Path) -> Bool {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path.string)
            return attributes[.type] as? FileAttributeType == .typeSymbolicLink
        } catch {
            return false
        }
    }
    
    func isReadable(_ path: Path) -> Bool {
        FileManager.default.isReadableFile(atPath: path.string)
    }
    
    func isWritable(_ path: Path) -> Bool {
        FileManager.default.isWritableFile(atPath: path.string)
    }
    
    func isExecutable(_ path: Path) -> Bool {
        FileManager.default.isExecutableFile(atPath: path.string)
    }
    
    func isDeletable(_ path: Path) -> Bool {
        FileManager.default.isDeletableFile(atPath: path.string)
    }
}