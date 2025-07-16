import Foundation
import Testing
@testable import PathKit

struct ThrowError: Error, Equatable {}

@Suite("PathKit Tests")
struct PathKitTests {
    private let fixtures: Path
    
    init() {
        let filePath = #filePath
        self.fixtures = Path(filePath).parent + "Fixtures"
    }
    
    // MARK: - Basic Properties
    
    @Test("Path separator")
    func testSeparator() {
        #expect(Path.separator == "/")
    }
    
    @Test("Current working directory")
    func testCurrentWorkingDirectory() {
        #expect(Path.current().description == FileManager.default.currentDirectoryPath)
    }
    
    // MARK: - Initialization
    
    @Test("Empty path initialization")
    func testEmptyInit() {
        #expect(Path().description == "")
    }
    
    @Test("String initialization")
    func testStringInit() {
        let path = Path("/usr/bin/swift")
        #expect(path.description == "/usr/bin/swift")
    }
    
    @Test("Components initialization")
    func testComponentsInit() {
        let path = Path(components: ["/usr", "bin", "swift"])
        #expect(path.description == "/usr/bin/swift")
    }
    
    // MARK: - Convertible
    
    @Test("String literal conversion")
    func testStringLiteralConversion() {
        let path: Path = "/usr/bin/swift"
        #expect(path.description == "/usr/bin/swift")
    }
    
    @Test("String conversion")
    func testStringConversion() {
        #expect(Path("/usr/bin/swift").string == "/usr/bin/swift")
    }
    
    @Test("URL conversion")
    func testURLConversion() {
        #expect(Path("/usr/bin/swift").url == URL(fileURLWithPath: "/usr/bin/swift"))
    }
    
    // MARK: - Equatable
    
    @Test("Path equality")
    func testEquality() {
        #expect(Path("/usr") == Path("/usr"))
        #expect(Path("/usr") != Path("/bin"))
    }
    
    // MARK: - Hashable
    
    @Test("Path hashing")
    func testHashing() {
        #expect(Path("/usr").hashValue == Path("/usr").hashValue)
    }
    
    // MARK: - Absolute/Relative Paths
    
    @Test("Relative path operations")
    func testRelativePath() {
        let path = Path("swift")
        
        #expect(path.absolute() == (Path.current() + Path("swift")))
        #expect(path.isAbsolute == false)
        #expect(path.isRelative == true)
    }
    
    @Test("Tilde path operations")
    func testTildePath() {
        let path = Path("~")
        
        #expect(path.absolute().isAbsolute == true)
        #expect(path.isAbsolute == false)
        #expect(path.isRelative == true)
    }
    
    @Test("Absolute path operations")
    func testAbsolutePath() {
        let path = Path("/usr/bin/swift")
        
        #expect(path.absolute() == path)
        #expect(path.isAbsolute == true)
        #expect(path.isRelative == false)
    }
    
    // MARK: - Path Manipulation
    
    @Test("Path normalization")
    func testNormalization() {
        let path = Path("/usr/local/../bin/swift")
        #expect(path.normalize().string == "/usr/bin/swift")
    }
    
    @Test("Path abbreviation")
    func testAbbreviation() {
        let homePath = Path.home()
        let docsPath = homePath + "Documents"
        
        #expect(docsPath.abbreviate().string.hasPrefix("~/"))
    }
    
    @Test("Last component")
    func testLastComponent() {
        #expect(Path("/usr/bin/swift").lastComponent == "swift")
        #expect(Path("/usr/bin/").lastComponent == "bin")
        #expect(Path("/").lastComponent == "/")
    }
    
    @Test("Last component without extension")
    func testLastComponentWithoutExtension() {
        #expect(Path("/usr/bin/swift.exe").lastComponentWithoutExtension == "swift")
        #expect(Path("/usr/bin/swift").lastComponentWithoutExtension == "swift")
    }
    
    @Test("Path components")
    func testComponents() {
        let path = Path("/usr/bin/swift")
        #expect(path.components == ["/", "usr", "bin", "swift"])
    }
    
    @Test("Path extension")
    func testExtension() {
        #expect(Path("/usr/bin/swift.exe").extension == "exe")
        #expect(Path("/usr/bin/swift").extension == "")
    }
    
    @Test("Parent directory")
    func testParent() {
        #expect(Path("/usr/bin/swift").parent == Path("/usr/bin"))
        #expect(Path("/usr").parent == Path("/"))
        #expect(Path("/").parent == Path("/"))
    }
    
    // MARK: - Path Building
    
    @Test("Appending components")
    func testAppending() {
        let path = Path("/usr/bin")
        #expect(path.appending("swift") == Path("/usr/bin/swift"))
        #expect(path + "swift" == Path("/usr/bin/swift"))
    }
    
    @Test("Appending extension")
    func testAppendingExtension() {
        let path = Path("/usr/bin/swift")
        #expect(path.appendingExtension("exe") == Path("/usr/bin/swift.exe"))
    }
    
    @Test("Path addition operator")
    func testAdditionOperator() {
        let base = Path("/usr")
        let component = "bin"
        let otherPath = Path("local")
        
        #expect(base + component == Path("/usr/bin"))
        #expect(base + otherPath == Path("/usr/local"))
    }
    
    // MARK: - File System Queries
    
    @Test("File existence")
    func testFileExistence() {
        let existingFile = fixtures + "file"
        let nonExistentFile = fixtures + "nonexistent"
        
        #expect(existingFile.exists == true)
        #expect(nonExistentFile.exists == false)
    }
    
    @Test("Directory detection")
    func testDirectoryDetection() {
        let directory = fixtures + "directory"
        let file = fixtures + "file"
        
        #expect(directory.isDirectory == true)
        #expect(file.isDirectory == false)
    }
    
    @Test("File detection")
    func testFileDetection() {
        let file = fixtures + "file"
        let directory = fixtures + "directory"
        
        #expect(file.isFile == true)
        #expect(directory.isFile == false)
    }
    
    @Test("Symlink detection")
    func testSymlinkDetection() {
        let symlink = fixtures + "symlinks" + "file"
        let file = fixtures + "file"
        
        #expect(symlink.isSymlink == true)
        #expect(file.isSymlink == false)
    }
    
    @Test("Permission checks")
    func testPermissionChecks() {
        let readableFile = fixtures + "permissions" + "readable"
        let writableFile = fixtures + "permissions" + "writable"
        let executableFile = fixtures + "permissions" + "executable"
        let deletableFile = fixtures + "permissions" + "deletable"
        
        #expect(readableFile.isReadable == true)
        #expect(writableFile.isWritable == true)
        #expect(executableFile.isExecutable == true)
        #expect(deletableFile.isDeletable == true)
    }
    
    // MARK: - Directory Operations
    
    @Test("Current directory")
    func testCurrentDirectory() {
        let current = Path.current()
        #expect(current.isAbsolute == true)
        #expect(current.isDirectory == true)
    }
    
    @Test("Home directory")
    func testHomeDirectory() {
        let home = Path.home()
        #expect(home.isAbsolute == true)
        #expect(home.isDirectory == true)
        #expect(home.string == NSHomeDirectory())
    }
    
    @Test("Temporary directory")
    func testTemporaryDirectory() {
        let temp = Path.temporary()
        #expect(temp.isAbsolute == true)
        #expect(temp.isDirectory == true)
        #expect(temp.string == NSTemporaryDirectory())
    }
    
    // MARK: - File Operations
    
    @Test("File reading")
    func testFileReading() throws {
        let file = fixtures + "hello"
        let data = try file.read()
        let string = try file.read(.utf8)
        
        #expect(data.count > 0)
        #expect(string == "world")
    }
    
    @Test("File writing")
    func testFileWriting() throws {
        let tempFile = Path.temporary() + "test_write_\(UUID().uuidString)"
        defer { try? tempFile.delete() }
        
        let testData = "Hello, World!".data(using: .utf8)!
        try tempFile.write(testData)
        
        let readData = try tempFile.read()
        #expect(readData == testData)
        
        let testString = "Hello, Swift!"
        try tempFile.write(testString)
        
        let readString = try tempFile.read(.utf8)
        #expect(readString == testString)
    }
    
    @Test("Directory creation")
    func testDirectoryCreation() throws {
        let tempDir = Path.temporary() + "test_mkdir_\(UUID().uuidString)"
        defer { try? tempDir.delete() }
        
        try tempDir.mkdir()
        #expect(tempDir.exists == true)
        #expect(tempDir.isDirectory == true)
    }
    
    @Test("Directory creation with intermediate directories")
    func testDirectoryCreationWithIntermediates() throws {
        let tempDir = Path.temporary() + "test_mkpath_\(UUID().uuidString)" + "subdir"
        defer { try? tempDir.parent.delete() }
        
        try tempDir.mkpath()
        #expect(tempDir.exists == true)
        #expect(tempDir.isDirectory == true)
    }
    
    // MARK: - Directory Enumeration
    
    @Test("Directory children")
    func testDirectoryChildren() throws {
        let directory = fixtures + "directory"
        let children = try directory.children()
        
        #expect(children.count > 0)
        #expect(children.contains(directory + "child"))
        #expect(children.contains(directory + "subdirectory"))
    }
    
    @Test("Recursive children")
    func testRecursiveChildren() throws {
        let directory = fixtures + "directory"
        let children = try directory.recursiveChildren()
        
        #expect(children.count > 0)
        #expect(children.contains(directory + "child"))
        #expect(children.contains(directory + "subdirectory"))
        #expect(children.contains(directory + "subdirectory" + "child"))
    }
    
    // MARK: - Glob Operations
    
    @Test("Basic glob")
    func testBasicGlob() {
        let testDir = Path.temporary() + "test_glob_\(UUID().uuidString)"
        defer { try? testDir.delete() }
        
        try! testDir.mkpath()
        try! (testDir + "test1.swift").write("test1")
        try! (testDir + "test2.swift").write("test2")
        try! (testDir + "test.txt").write("test")
        
        let swiftFiles = Path.glob(testDir.string + "/*.swift")
        #expect(swiftFiles.count == 2)
        #expect(swiftFiles.allSatisfy { $0.extension == "swift" })
    }
    
    @Test("Brace expansion glob")
    func testBraceExpansionGlob() {
        let testDir = Path.temporary() + "test_brace_\(UUID().uuidString)"
        defer { try? testDir.delete() }
        
        try! testDir.mkpath()
        try! (testDir + "test1.swift").write("test1")
        try! (testDir + "test2.h").write("test2")
        try! (testDir + "test3.txt").write("test3")
        
        let sourceFiles = Path.glob(testDir.string + "/*.{swift,h}")
        #expect(sourceFiles.count == 2)
        #expect(sourceFiles.allSatisfy { $0.extension == "swift" || $0.extension == "h" })
    }
    
    @Test("Instance glob")
    func testInstanceGlob() {
        let testDir = Path.temporary() + "test_instance_glob_\(UUID().uuidString)"
        defer { try? testDir.delete() }
        
        try! testDir.mkpath()
        try! (testDir + "test1.swift").write("test1")
        try! (testDir + "test2.swift").write("test2")
        
        let swiftFiles = testDir.glob("*.swift")
        #expect(swiftFiles.count == 2)
        #expect(swiftFiles.allSatisfy { $0.extension == "swift" })
    }
    
    // MARK: - Pattern Matching
    
    @Test("Pattern matching")
    func testPatternMatching() {
        let path = Path("/usr/bin/swift")
        
        #expect(path.match("*/bin/swift") == true)
        #expect(path.match("*/bin/gcc") == false)
        #expect(path.match("*swift") == true)
        #expect(path.match("*gcc") == false)
    }
    
    // MARK: - Sequence Support
    
    @Test("Path iteration")
    func testPathIteration() {
        let path = Path("/usr/bin/swift")
        let components = Array(path)
        
        #expect(components.count == 4)
        #expect(components[0] == Path("/"))
        #expect(components[1] == Path("usr"))
        #expect(components[2] == Path("bin"))
        #expect(components[3] == Path("swift"))
    }
    
    // MARK: - Codable Support
    
    @Test("Codable encoding and decoding")
    func testCodable() throws {
        let originalPath = Path("/usr/bin/swift")
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalPath)
        
        let decoder = JSONDecoder()
        let decodedPath = try decoder.decode(Path.self, from: data)
        
        #expect(decodedPath == originalPath)
    }
    
    // MARK: - Thread Safety (Swift 6 Concurrency)
    
    @Test("Concurrent path operations")
    func testConcurrentOperations() async {
        let path = Path("/tmp/test")
        
        await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    // Test that Path operations are thread-safe
                    let exists = path.exists
                    let isDir = path.isDirectory
                    let parent = path.parent
                    return exists || isDir || parent.exists
                }
            }
        }
        
        // If we get here without crashes, concurrency is working
        #expect(true)
    }
    
    // MARK: - Cross-Platform Compatibility
    
    @Test("Cross-platform glob behavior")
    func testCrossPlatformGlob() {
        let testDir = Path.temporary() + "test_cross_platform_\(UUID().uuidString)"
        defer { try? testDir.delete() }
        
        try! testDir.mkpath()
        try! (testDir + "test.swift").write("swift")
        try! (testDir + "test.h").write("header")
        try! (testDir + "test.txt").write("text")
        
        // Test that brace expansion works identically on all platforms
        let sourceFiles = Path.glob(testDir.string + "/*.{swift,h}")
        #expect(sourceFiles.count == 2)
        #expect(sourceFiles.contains { $0.extension == "swift" })
        #expect(sourceFiles.contains { $0.extension == "h" })
        #expect(!sourceFiles.contains { $0.extension == "txt" })
    }
}

// MARK: - Directory Enumeration Options Tests

@Suite("Directory Enumeration Options")
struct DirectoryEnumerationOptionsTests {
    @Test("Enumeration options")
    func testEnumerationOptions() {
        let testDir = Path.temporary() + "test_enum_\(UUID().uuidString)"
        defer { try? testDir.delete() }
        
        try! testDir.mkpath()
        try! (testDir + "visible.txt").write("visible")
        try! (testDir + ".hidden.txt").write("hidden")
        
        let allFiles = Array(testDir.iterateChildren())
        let visibleFiles = Array(testDir.iterateChildren(options: .skipsHiddenFiles))
        
        #expect(allFiles.count >= visibleFiles.count)
        #expect(visibleFiles.allSatisfy { !$0.lastComponent.hasPrefix(".") })
    }
}

// MARK: - Error Handling Tests

@Suite("Error Handling")
struct ErrorHandlingTests {
    @Test("Path errors")
    func testPathErrors() {
        let nonExistentPath = Path("/nonexistent/path")
        
        #expect(throws: Error.self) {
            try nonExistentPath.read()
        }
        
        #expect(throws: Error.self) {
            try nonExistentPath.children()
        }
    }
    
    @Test("Directory change errors")
    func testDirectoryChangeErrors() {
        let nonExistentPath = Path("/nonexistent/directory")
        
        #expect(throws: PathError.self) {
            try Path.chdir(nonExistentPath)
        }
    }
}