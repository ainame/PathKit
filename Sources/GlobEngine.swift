// Foundation-based glob engine for cross-platform compatibility

import Foundation

// MARK: - Glob Engine Protocol

internal protocol GlobEngine: Sendable {
    func glob(_ pattern: String) -> [String]
}

// MARK: - Foundation Glob Engine (Pure Swift for Musl compatibility)

internal struct FoundationGlobEngine: GlobEngine {
    // Don't store FileManager - just access it directly (it's thread-safe)
    
    func glob(_ pattern: String) -> [String] {
        // Special case: empty pattern returns empty array (match C behavior)
        if pattern.isEmpty {
            return []
        }
        
        // Step 1: Expand tilde
        let expandedPattern = expandTilde(pattern)
        
        // Special case: if pattern is just "~", return home directory with trailing slash
        if pattern == "~" {
            return [NSHomeDirectory() + "/"]
        }
        
        // Step 2: Expand braces {a,b,c} -> [a, b, c]
        let patterns = expandBraces(expandedPattern)
        
        // Step 3: Process each pattern
        var allResults: Set<String> = []
        for pat in patterns {
            allResults.formUnion(Set(globSingle(pat)))
        }
        
        // Step 4: Sort and return
        return Array(allResults).sorted()
    }
    
    private func expandTilde(_ pattern: String) -> String {
        guard pattern.hasPrefix("~") else { return pattern }
        return (pattern as NSString).expandingTildeInPath
    }
    
    private func expandBraces(_ pattern: String) -> [String] {
        // Find brace expressions like {a,b,c} or {}
        let braceRegex = try! NSRegularExpression(pattern: #"\{([^}]*)\}"#)
        let matches = braceRegex.matches(in: pattern, range: NSRange(pattern.startIndex..., in: pattern))
        
        guard let firstMatch = matches.first else {
            return [pattern] // No braces found
        }
        
        let braceContent = String(pattern[Range(firstMatch.range(at: 1), in: pattern)!])
        
        // Handle empty braces - they should be treated as no braces (removed)
        if braceContent.isEmpty {
            let prefix = String(pattern[..<Range(firstMatch.range, in: pattern)!.lowerBound])
            let suffix = String(pattern[Range(firstMatch.range, in: pattern)!.upperBound...])
            return expandBraces(prefix + suffix)
        }
        
        let alternatives = braceContent.split(separator: ",").map(String.init)
        
        let prefix = String(pattern[..<Range(firstMatch.range, in: pattern)!.lowerBound])
        let suffix = String(pattern[Range(firstMatch.range, in: pattern)!.upperBound...])
        
        var results: [String] = []
        for alt in alternatives {
            let newPattern = prefix + alt + suffix
            // Recursively expand any remaining braces
            results.append(contentsOf: expandBraces(newPattern))
        }
        
        return results
    }
    
    private func globSingle(_ pattern: String) -> [String] {
        // Special case: if pattern ends with "/" and has no wildcards, just check if directory exists
        if pattern.hasSuffix("/") && !pattern.contains("*") && !pattern.contains("?") && !pattern.contains("[") {
            let dirPath = String(pattern.dropLast())
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: dirPath, isDirectory: &isDir) && isDir.boolValue {
                return [pattern] // Return with the original trailing slash
            }
            return []
        }
        
        // Split pattern into directory components
        let components = pattern.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        let isAbsolute = pattern.hasPrefix("/")
        
        let startPath = isAbsolute ? "/" : "."
        let results = Array(globRecursive(components: Array(components.drop(while: { $0.isEmpty })), 
                                         currentPath: startPath))
        
        // For relative paths, remove "./" prefix to match C glob behavior
        if !isAbsolute {
            return results.map { path in
                if path.hasPrefix("./") {
                    return String(path.dropFirst(2))
                }
                return path
            }
        }
        
        return results
    }
    
    private func globRecursive(components: [String], currentPath: String) -> Set<String> {
        guard !components.isEmpty else {
            return [currentPath]
        }
        
        let currentComponent = components[0]
        let remainingComponents = Array(components.dropFirst())
        
        var results: Set<String> = []
        
        // Handle wildcards and patterns
        if currentComponent.contains("*") || currentComponent.contains("?") || currentComponent.contains("[") {
            // Get directory contents and match pattern
            do {
                let url = URL(fileURLWithPath: currentPath)
                let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey])
                
                // First check . and .. entries if pattern explicitly matches hidden files (to match C glob behavior)
                if currentComponent.hasPrefix(".") {
                    // Check . (current directory)
                    if matchesPattern(".", pattern: currentComponent) {
                        let nextPath = currentPath == "/" ? "/." : "\(currentPath)/."
                        if remainingComponents.isEmpty {
                            results.insert(nextPath + "/")
                        }
                    }
                    
                    // Check .. (parent directory)
                    if currentPath != "/" && matchesPattern("..", pattern: currentComponent) {
                        let nextPath = currentPath == "/" ? "/.." : "\(currentPath)/.."
                        if remainingComponents.isEmpty {
                            results.insert(nextPath + "/")
                        }
                    }
                }
                
                for itemURL in contents {
                    let itemName = itemURL.lastPathComponent
                    
                    // Skip hidden files unless pattern explicitly matches them (match C glob behavior)
                    if itemName.hasPrefix(".") && !currentComponent.hasPrefix(".") {
                        continue
                    }
                    
                    if matchesPattern(itemName, pattern: currentComponent) {
                        let nextPath = currentPath == "/" ? "/\(itemName)" : "\(currentPath)/\(itemName)"
                        
                        if remainingComponents.isEmpty {
                            // Final component - add if it matches
                            // Check if it's a directory and add trailing slash (GLOB_MARK behavior)
                            let isDir = (try? itemURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                            results.insert(isDir ? nextPath + "/" : nextPath)
                        } else {
                            // More components - recurse only if this is a directory
                            let isDir = (try? itemURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                            if isDir {
                                results.formUnion(globRecursive(components: remainingComponents, 
                                                              currentPath: nextPath))
                            }
                        }
                    }
                }
            } catch {
                // Directory doesn't exist or can't be read
                return []
            }
        } else {
            // Literal component
            let nextPath = currentPath == "/" ? "/\(currentComponent)" : "\(currentPath)/\(currentComponent)"
            
            if remainingComponents.isEmpty {
                // Final component - check if it exists
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: nextPath, isDirectory: &isDir) {
                    // Add trailing slash for directories (GLOB_MARK behavior)
                    results.insert(isDir.boolValue ? nextPath + "/" : nextPath)
                }
            } else {
                // More components - recurse if directory exists
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: nextPath, isDirectory: &isDir) && isDir.boolValue {
                    results.formUnion(globRecursive(components: remainingComponents, 
                                                  currentPath: nextPath))
                }
            }
        }
        
        return results
    }
    
    private func matchesPattern(_ string: String, pattern: String) -> Bool {
        // Convert glob pattern to regex
        let regexPattern = globToRegex(pattern)
        do {
            let regex = try NSRegularExpression(pattern: regexPattern)
            let range = NSRange(string.startIndex..., in: string)
            return regex.firstMatch(in: string, range: range) != nil
        } catch {
            return false
        }
    }
    
    private func globToRegex(_ pattern: String) -> String {
        var regex = "^"
        var i = pattern.startIndex
        
        while i < pattern.endIndex {
            let char = pattern[i]
            
            switch char {
            case "*":
                regex += "[^/]*"
            case "?":
                regex += "[^/]"
            case "[":
                // Character class - find the closing bracket
                let start = i
                i = pattern.index(after: i)
                var classContent = ""
                
                // Check for negation
                var negated = false
                if i < pattern.endIndex && pattern[i] == "!" {
                    negated = true
                    i = pattern.index(after: i)
                }
                
                // Collect the character class content
                while i < pattern.endIndex && pattern[i] != "]" {
                    classContent.append(pattern[i])
                    i = pattern.index(after: i)
                }
                
                if i < pattern.endIndex {
                    // Build the regex character class
                    if negated {
                        regex += "[^" + classContent + "]"
                    } else {
                        regex += "[" + classContent + "]"
                    }
                } else {
                    regex += "\\["
                    i = start
                }
            case ".":
                regex += "\\."
            case "^", "$", "(", ")", "+", "{", "}", "|", "\\":
                regex += "\\" + String(char)
            default:
                regex += String(char)
            }
            
            i = pattern.index(after: i)
        }
        
        regex += "$"
        return regex
    }
}

// MARK: - C-based Glob Engine (Performance for Glibc/Darwin)

#if canImport(Darwin) || (canImport(Glibc) && !canImport(Musl))

/// High-performance C-based glob implementation for Glibc/Darwin systems
/// Note: Not used on Musl systems - they use FoundationGlobEngine instead
internal struct CGlobEngine: GlobEngine {
    func glob(_ pattern: String) -> [String] {
        var gt = glob_t()
        guard let cPattern = strdup(pattern) else {
            return []
        }
        defer {
            globfree(&gt)
            free(cPattern)
        }
        
        let flags = getGlobFlags()
        if system_glob(cPattern, flags, nil, &gt) == 0 {
            #if os(Linux)
            let matchc = gt.gl_pathc
            #else
            let matchc = gt.gl_matchc
            #endif
            return (0..<Int(matchc)).compactMap { index in
                if let path = String(validatingCString: gt.gl_pathv[index]!) {
                    return path
                }
                return nil
            }
        }
        
        return []
    }
    
    private func getGlobFlags() -> Int32 {
        #if os(Linux) && canImport(Glibc)
          // Glibc constants
          let GLOB_BRACE = Glibc.GLOB_BRACE
          let GLOB_TILDE = Glibc.GLOB_TILDE
          let GLOB_MARK = Glibc.GLOB_MARK
        #else
          // Darwin constants
          let GLOB_BRACE = Darwin.GLOB_BRACE
          let GLOB_TILDE = Darwin.GLOB_TILDE
          let GLOB_MARK = Darwin.GLOB_MARK
        #endif
        
        return GLOB_TILDE | GLOB_BRACE | GLOB_MARK
    }
}

// Platform-specific system_glob function (only used by CGlobEngine)
#if os(Linux) && canImport(Glibc)
  import Glibc
  let system_glob = Glibc.glob
#else
  import Darwin
  let system_glob = Darwin.glob
#endif

#endif

// MARK: - Glob Engine Factory

internal enum GlobEngineFactory {
    static func makeEngine() -> GlobEngine {
        #if canImport(Musl)
        // Always use Foundation-based implementation for Musl compatibility
        // Musl's glob() behavior differs from Glibc, so we use consistent Swift implementation
        return FoundationGlobEngine()
        #else
        // Use C-based implementation for performance on Glibc/Darwin
        return CGlobEngine()
        #endif
    }
}