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
        // Step 1: Expand tilde
        let expandedPattern = expandTilde(pattern)
        
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
        // Find brace expressions like {a,b,c}
        let braceRegex = try! NSRegularExpression(pattern: #"\{([^}]+)\}"#)
        let matches = braceRegex.matches(in: pattern, range: NSRange(pattern.startIndex..., in: pattern))
        
        guard let firstMatch = matches.first else {
            return [pattern] // No braces found
        }
        
        let braceContent = String(pattern[Range(firstMatch.range(at: 1), in: pattern)!])
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
        // Split pattern into directory components
        let components = pattern.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        let isAbsolute = pattern.hasPrefix("/")
        
        let startPath = isAbsolute ? "/" : "."
        return Array(globRecursive(components: Array(components.drop(while: { $0.isEmpty })), 
                                 currentPath: startPath))
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
                
                for itemURL in contents {
                    let itemName = itemURL.lastPathComponent
                    if matchesPattern(itemName, pattern: currentComponent) {
                        let nextPath = currentPath == "/" ? "/\(itemName)" : "\(currentPath)/\(itemName)"
                        
                        if remainingComponents.isEmpty {
                            // Final component - add if it matches
                            results.insert(nextPath)
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
                if FileManager.default.fileExists(atPath: nextPath) {
                    results.insert(nextPath)
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
                while i < pattern.endIndex && pattern[i] != "]" {
                    i = pattern.index(after: i)
                }
                if i < pattern.endIndex {
                    regex += String(pattern[start...i])
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
        #if os(Linux)
          #if canImport(Musl)
            // Musl constants
            let GLOB_BRACE: Int32 = 0  // Not supported
            let GLOB_TILDE: Int32 = 0x1000
            let GLOB_MARK: Int32 = 0x02
          #else
            // Glibc constants
            let GLOB_BRACE = Glibc.GLOB_BRACE
            let GLOB_TILDE = Glibc.GLOB_TILDE
            let GLOB_MARK = Glibc.GLOB_MARK
          #endif
        #else
          // Darwin constants
          let GLOB_BRACE = Darwin.GLOB_BRACE
          let GLOB_TILDE = Darwin.GLOB_TILDE
          let GLOB_MARK = Darwin.GLOB_MARK
        #endif
        
        return GLOB_TILDE | GLOB_BRACE | GLOB_MARK
    }
}

// Platform-specific system_glob function
#if os(Linux)
  #if canImport(Musl)
    import Musl
    let system_glob = Musl.glob
  #else
    import Glibc
    let system_glob = Glibc.glob
  #endif
#else
  import Darwin
  let system_glob = Darwin.glob
#endif

#endif

// MARK: - Glob Engine Factory

internal enum GlobEngineFactory {
    static func makeEngine() -> GlobEngine {
        #if canImport(Musl)
        // Always use Foundation for Musl
        return FoundationGlobEngine()
        #else
        // Use C-based for performance on Glibc/Darwin
        return CGlobEngine()
        #endif
    }
}