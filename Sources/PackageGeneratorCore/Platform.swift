//
//  Platform.swift
//  PackageGeneratorCore
//
//  Created by Stephane Magne on 2026-01-24.
//

public enum Platform {
    case macOS(majorVersion: Int)
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
        case .macOS(let version):
            // macOS 10.x uses special syntax
            if version < 11 {
                return ".macOS(.v10_\(version))"
            } else {
                return ".macOS(.v\(version))"
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

// MARK: - Equatable

extension Platform: Equatable {
    public static func == (lhs: Platform, rhs: Platform) -> Bool {
        switch (lhs, rhs) {
        case (.macOS(let v1), .macOS(let v2)):
            return v1 == v2
        case (.iOS(let v1), .iOS(let v2)):
            return v1 == v2
        case (.tvOS(let v1), .tvOS(let v2)):
            return v1 == v2
        case (.watchOS(let v1), .watchOS(let v2)):
            return v1 == v2
        case (.visionOS(let v1), .visionOS(let v2)):
            return v1 == v2
        case (.linux, .linux):
            return true
        default:
            return false
        }
    }
}
