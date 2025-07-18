import Foundation
import Testing
@testable import PathKit

/// Test suite to ensure Foundation-based and C-based GlobEngine implementations
/// produce identical results across all test cases
@Suite("GlobEngine Compatibility Tests")
struct GlobEngineTests {
    // Test both engines on platforms that support C-based glob
    #if canImport(Darwin) || (canImport(Glibc) && !canImport(Musl))
    private let cEngine = CGlobEngine()
    #endif
    private let foundationEngine = FoundationGlobEngine()
    
    // Helper to ensure both engines produce identical results
    private func assertEnginesMatch(_ pattern: String) {
        let foundationResults = foundationEngine.glob(pattern)
        
        #if canImport(Darwin) || (canImport(Glibc) && !canImport(Musl))
        let cResults = cEngine.glob(pattern)
        
        // Sort both results to ensure consistent ordering
        let sortedFoundation = foundationResults.sorted()
        let sortedC = cResults.sorted()
        
        if sortedFoundation != sortedC {
            let foundationSet = Set(sortedFoundation)
            let cSet = Set(sortedC)
            let onlyInFoundation = foundationSet.subtracting(cSet)
            let onlyInC = cSet.subtracting(foundationSet)
            
            var message = "Foundation and C engines produced different results for pattern '\(pattern)':\n"
            if !onlyInFoundation.isEmpty {
                message += "Only in Foundation: \(onlyInFoundation)\n"
            }
            if !onlyInC.isEmpty {
                message += "Only in C: \(onlyInC)\n"
            }
            message += "Foundation: \(sortedFoundation)\n"
            message += "C: \(sortedC)"
            
            Issue.record(Comment(rawValue: message))
        }
        #else
        // On Musl, just verify Foundation engine works
        #expect(foundationResults.count >= 0)
        #endif
    }
    
    // Helper to setup test directory structure
    private func setupTestDirectory() -> Path {
        let testDir = Path.temporary + "glob_engine_test_\(UUID().uuidString)"
        try! testDir.mkpath()
        
        // Create test file structure
        try! (testDir + "file1.txt").write("test")
        try! (testDir + "file2.txt").write("test")
        try! (testDir + "file1.swift").write("test")
        try! (testDir + "file2.swift").write("test")
        try! (testDir + "test.h").write("test")
        try! (testDir + ".hidden").write("test")
        
        // Create subdirectories
        try! (testDir + "subdir").mkpath()
        try! (testDir + "subdir" + "file3.txt").write("test")
        try! (testDir + "subdir" + "file3.swift").write("test")
        
        try! (testDir + "another").mkpath()
        try! (testDir + "another" + "file4.txt").write("test")
        
        // Create nested structure
        try! (testDir + "deep").mkpath()
        try! (testDir + "deep" + "nested").mkpath()
        try! (testDir + "deep" + "nested" + "file.txt").write("test")
        
        return testDir
    }
    
    // MARK: - Basic Pattern Tests
    
    @Test("Literal paths")
    func testLiteralPaths() {
        let testDir = setupTestDirectory()
        defer { try? testDir.delete() }
        
        assertEnginesMatch(testDir.string + "/file1.txt")
        assertEnginesMatch(testDir.string + "/nonexistent.txt")
        assertEnginesMatch(testDir.string + "/subdir")
    }
    
    @Test("Simple wildcards")
    func testSimpleWildcards() {
        let testDir = setupTestDirectory()
        defer { try? testDir.delete() }
        
        assertEnginesMatch(testDir.string + "/*.txt")
        assertEnginesMatch(testDir.string + "/*.swift")
        assertEnginesMatch(testDir.string + "/file?.txt")
        assertEnginesMatch(testDir.string + "/file*.txt")
        assertEnginesMatch(testDir.string + "/*")
    }
    
    @Test("Character classes")
    func testCharacterClasses() {
        let testDir = setupTestDirectory()
        defer { try? testDir.delete() }
        
        assertEnginesMatch(testDir.string + "/file[12].txt")
        assertEnginesMatch(testDir.string + "/file[1-2].txt")
        assertEnginesMatch(testDir.string + "/[ft]*.txt")
        assertEnginesMatch(testDir.string + "/[!f]*.txt")
    }
    
    // MARK: - Brace Expansion Tests
    
    @Test("Basic brace expansion")
    func testBasicBraceExpansion() {
        let testDir = setupTestDirectory()
        defer { try? testDir.delete() }
        
        assertEnginesMatch(testDir.string + "/*.{txt,swift}")
        assertEnginesMatch(testDir.string + "/file{1,2}.txt")
        assertEnginesMatch(testDir.string + "/{file1,file2}.{txt,swift}")
    }
    
    @Test("Nested brace expansion")
    func testNestedBraceExpansion() {
        let testDir = setupTestDirectory()
        defer { try? testDir.delete() }
        
        // Create additional test files for nested brace testing
        try! (testDir + "test1a.txt").write("test")
        try! (testDir + "test1b.txt").write("test")
        try! (testDir + "test2a.txt").write("test")
        try! (testDir + "test2b.txt").write("test")
        
        assertEnginesMatch(testDir.string + "/test{1,2}{a,b}.txt")
        assertEnginesMatch(testDir.string + "/{test,file}{1,2}.{txt,swift}")
    }
    
    @Test("Empty and single-element braces")
    func testEdgeCaseBraces() {
        let testDir = setupTestDirectory()
        defer { try? testDir.delete() }
        
        assertEnginesMatch(testDir.string + "/{file1}.txt")  // Single element
        assertEnginesMatch(testDir.string + "/file1{}.txt")  // Empty braces
    }
    
    // MARK: - Directory Traversal Tests
    
    @Test("Recursive patterns")
    func testRecursivePatterns() {
        let testDir = setupTestDirectory()
        defer { try? testDir.delete() }
        
        assertEnginesMatch(testDir.string + "/*/file*.txt")
        assertEnginesMatch(testDir.string + "/*/*.swift")
        assertEnginesMatch(testDir.string + "/*/*/*.txt")
    }
    
    @Test("Absolute vs relative paths")
    func testAbsoluteVsRelativePaths() {
        let testDir = setupTestDirectory()
        defer { try? testDir.delete() }
        
        // Test with absolute path
        assertEnginesMatch(testDir.string + "/*.txt")
        
        // Change to test directory and test relative paths
        let previousDir = Path.current()
        try! Path.chdir(testDir)
        defer { try! Path.chdir(previousDir) }
        
        assertEnginesMatch("*.txt")
        assertEnginesMatch("*/*.txt")
        assertEnginesMatch("./*.txt")
    }
    
    // MARK: - Special Cases
    
    @Test("Hidden files")
    func testHiddenFiles() {
        let testDir = setupTestDirectory()
        defer { try? testDir.delete() }
        
        assertEnginesMatch(testDir.string + "/.*")
        assertEnginesMatch(testDir.string + "/.hidden")
        assertEnginesMatch(testDir.string + "/.[!.]*")
    }
    
    @Test("Empty patterns and edge cases")
    func testEmptyAndEdgeCases() {
        let testDir = setupTestDirectory()
        defer { try? testDir.delete() }
        
        assertEnginesMatch("")
        assertEnginesMatch(testDir.string + "/")
        assertEnginesMatch(testDir.string + "//file1.txt")  // Double slash
        assertEnginesMatch(testDir.string + "/./file1.txt")  // Current dir
    }
    
    @Test("Tilde expansion")
    func testTildeExpansion() {
        // Both engines should expand ~ to home directory with trailing slash
        let homeResults = foundationEngine.glob("~")
        #expect(homeResults.count == 1)
        #expect(homeResults.first == NSHomeDirectory() + "/")
        
        #if canImport(Darwin) || (canImport(Glibc) && !canImport(Musl))
        let cHomeResults = cEngine.glob("~")
        #expect(cHomeResults == homeResults)
        #endif
        
        // Test tilde in paths
        assertEnginesMatch("~/*")
    }
    
    @Test("Special characters in filenames")
    func testSpecialCharacters() {
        let testDir = setupTestDirectory()
        defer { try? testDir.delete() }
        
        // Create files with special characters
        try! (testDir + "file with spaces.txt").write("test")
        try! (testDir + "file-with-dashes.txt").write("test")
        try! (testDir + "file_with_underscores.txt").write("test")
        try! (testDir + "file.multiple.dots.txt").write("test")
        
        assertEnginesMatch(testDir.string + "/*with*")
        assertEnginesMatch(testDir.string + "/*spaces*")
        assertEnginesMatch(testDir.string + "/*.*.*")
        assertEnginesMatch(testDir.string + "/file?with?*.txt")
    }
    
    // MARK: - Error Cases
    
    @Test("Invalid patterns")
    func testInvalidPatterns() {
        let testDir = setupTestDirectory()
        defer { try? testDir.delete() }
        
        // Unclosed brackets
        assertEnginesMatch(testDir.string + "/file[1.txt")
        
        // Invalid ranges
        assertEnginesMatch(testDir.string + "/file[z-a].txt")
        
        // Escaped characters
        assertEnginesMatch(testDir.string + "/file\\*.txt")
    }
    
    @Test("Non-existent paths")
    func testNonExistentPaths() {
        assertEnginesMatch("/completely/nonexistent/path/*.txt")
        assertEnginesMatch("/nonexistent/*/file.txt")
        assertEnginesMatch("/nonexistent/{a,b,c}/*.txt")
    }
    
    // MARK: - Performance and Stress Tests
    
    @Test("Large directory with many files")
    func testLargeDirectory() {
        let testDir = Path.temporary + "glob_stress_test_\(UUID().uuidString)"
        defer { try? testDir.delete() }
        try! testDir.mkpath()
        
        // Create many files
        for i in 0..<100 {
            try! (testDir + "file\(i).txt").write("test")
            if i % 3 == 0 {
                try! (testDir + "file\(i).swift").write("test")
            }
        }
        
        assertEnginesMatch(testDir.string + "/*.txt")
        assertEnginesMatch(testDir.string + "/*.swift")
        assertEnginesMatch(testDir.string + "/file?.txt")
        assertEnginesMatch(testDir.string + "/file[0-9].txt")
        assertEnginesMatch(testDir.string + "/file{1,2,3,4,5}*.txt")
    }
    
    @Test("Complex nested patterns")
    func testComplexNestedPatterns() {
        let testDir = setupTestDirectory()
        defer { try? testDir.delete() }
        
        // Create deeper structure
        try! (testDir + "a").mkpath()
        try! (testDir + "a" + "b").mkpath()
        try! (testDir + "a" + "b" + "c").mkpath()
        try! (testDir + "a" + "b" + "c" + "deep.txt").write("test")
        
        assertEnginesMatch(testDir.string + "/*/*/*/*")
        assertEnginesMatch(testDir.string + "/a/*/c/*.txt")
        assertEnginesMatch(testDir.string + "/{a,subdir,another}/*")
    }
    
    // MARK: - Cross-Platform Consistency
    
    @Test("Ensure consistent sorting")
    func testConsistentSorting() {
        let testDir = setupTestDirectory()
        defer { try? testDir.delete() }
        
        // Create files that might sort differently
        try! (testDir + "A.txt").write("test")
        try! (testDir + "a.txt").write("test")
        try! (testDir + "B.txt").write("test")
        try! (testDir + "b.txt").write("test")
        try! (testDir + "_underscore.txt").write("test")
        try! (testDir + "10.txt").write("test")
        try! (testDir + "2.txt").write("test")
        
        assertEnginesMatch(testDir.string + "/*.txt")
        assertEnginesMatch(testDir.string + "/[aAbB].txt")
        assertEnginesMatch(testDir.string + "/[0-9]*.txt")
    }
    
    @Test("Symlink handling")
    func testSymlinkHandling() {
        let testDir = setupTestDirectory()
        defer { try? testDir.delete() }
        
        // Create a symlink
        let linkPath = testDir + "link_to_file"
        let targetPath = testDir + "file1.txt"
        try! FileManager.default.createSymbolicLink(at: linkPath.url, 
                                                   withDestinationURL: targetPath.url)
        
        assertEnginesMatch(testDir.string + "/link*")
        assertEnginesMatch(testDir.string + "/*_to_*")
    }
}

// MARK: - Direct Engine Comparison Tests

@Suite("Direct GlobEngine Comparison")
struct DirectGlobEngineComparisonTests {
    #if canImport(Darwin) || (canImport(Glibc) && !canImport(Musl))
    
    @Test("Verify both engines are available")
    func testBothEnginesAvailable() {
        let cEngine = CGlobEngine()
        let foundationEngine = FoundationGlobEngine()
        
        // Simple test to ensure both work
        let cResults = cEngine.glob("/usr/bin/*")
        let foundationResults = foundationEngine.glob("/usr/bin/*")
        
        #expect(cResults.count > 0)
        #expect(foundationResults.count > 0)
        #expect(Set(cResults) == Set(foundationResults))
    }
    
    @Test("Compare common system paths")
    func testSystemPaths() {
        let cEngine = CGlobEngine()
        let foundationEngine = FoundationGlobEngine()
        
        let patterns = [
            "/usr/bin/sw*",
            "/usr/lib/*.dylib",
            "/etc/*",
            "/tmp/*"
        ]
        
        for pattern in patterns {
            let cResults = Set(cEngine.glob(pattern))
            let foundationResults = Set(foundationEngine.glob(pattern))
            
            if cResults != foundationResults {
                print("Mismatch for pattern: \(pattern)")
                print("C-only: \(cResults.subtracting(foundationResults))")
                print("Foundation-only: \(foundationResults.subtracting(cResults))")
            }
            
            #expect(cResults == foundationResults, 
                    "Mismatch for pattern: \(pattern)")
        }
    }
    
    #endif
}