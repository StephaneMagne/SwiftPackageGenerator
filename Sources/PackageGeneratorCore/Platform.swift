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
            return ".macOS(.v\(version))"
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
