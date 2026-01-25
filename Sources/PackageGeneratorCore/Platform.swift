//
//  Platform.swift
//  PackageGeneratorCore
//
//  Created by Stephane Magne on 2026-01-24.
//

public enum Platform: Hashable {
    case macOS(majorVersion: Int, minorVersion: Int? = nil)
    case iOS(majorVersion: Int)
    case tvOS(majorVersion: Int)
    case watchOS(majorVersion: Int)
    case visionOS(majorVersion: Int)
    case linux
}

// MARK: - Rendering

extension Platform {
    var rendered: String {
        switch self {
        case .macOS(let majorVersion, let minorVersion):
            // macOS 10.x uses special syntax
            if let minorVersion {
                return ".macOS(.v\(majorVersion)_\(minorVersion))"
            } else {
                return ".macOS(.v\(majorVersion))"
            }
        case .iOS(let version):
            return ".iOS(.v\(version))"
        case .tvOS(let version):
            return ".tvOS(.v\(version))"
        case .watchOS(let version):
            return ".watchOS(.v\(version))"
        case .visionOS(let version):
            return ".visionOS(.v\(version))"
        case .linux:
            return ".linux"
        }
    }
}

// MARK: - Deduplication

extension Platform {
    /// Deduplicates platforms, keeping the highest version for each platform type
    static func deduplicate(_ platforms: [Platform]) -> [Platform] {
        var result: [Platform] = []
        var seenMacOS: (major: Int, minor: Int?)?
        var seeniOS: Int?
        var seenTvOS: Int?
        var seenWatchOS: Int?
        var seenVisionOS: Int?
        var seenLinux = false
        
        for platform in platforms {
            switch platform {
            case .macOS(let majorVersion, let minorVersion):
                if let (existingMajor, existingMinor) = seenMacOS {
                    // Major version always wins
                    if majorVersion > existingMajor {
                        seenMacOS = (majorVersion, minorVersion)
                    } else if majorVersion == existingMajor {
                        // Same major: explicit minor wins over nil
                        switch (existingMinor, minorVersion) {
                        case (nil, let minor?):
                            // New has explicit minor, existing doesn't → use new
                            seenMacOS = (majorVersion, minor)
                        case (let existingMinor?, let minor?):
                            // Both explicit → keep highest
                            seenMacOS = (majorVersion, max(existingMinor, minor))
                        default:
                            // Keep existing (covers nil/nil and minor?/nil cases)
                            break
                        }
                    }
                    // else: existing major is higher, keep it
                } else {
                    seenMacOS = (majorVersion, minorVersion)
                }
            case .iOS(let version):
                if let existing = seeniOS {
                    seeniOS = max(existing, version)
                } else {
                    seeniOS = version
                }
            case .tvOS(let version):
                if let existing = seenTvOS {
                    seenTvOS = max(existing, version)
                } else {
                    seenTvOS = version
                }
            case .watchOS(let version):
                if let existing = seenWatchOS {
                    seenWatchOS = max(existing, version)
                } else {
                    seenWatchOS = version
                }
            case .visionOS(let version):
                if let existing = seenVisionOS {
                    seenVisionOS = max(existing, version)
                } else {
                    seenVisionOS = version
                }
            case .linux:
                seenLinux = true
            }
        }
        
        // Build result in consistent order: macOS, iOS, tvOS, watchOS, visionOS, linux
        if let (majorVersion, minorVersion) = seenMacOS {
            result.append(.macOS(majorVersion: majorVersion, minorVersion: minorVersion))
        }
        if let version = seeniOS {
            result.append(.iOS(majorVersion: version))
        }
        if let version = seenTvOS {
            result.append(.tvOS(majorVersion: version))
        }
        if let version = seenWatchOS {
            result.append(.watchOS(majorVersion: version))
        }
        if let version = seenVisionOS {
            result.append(.visionOS(majorVersion: version))
        }
        if seenLinux {
            result.append(.linux)
        }
        
        return result
    }
}
