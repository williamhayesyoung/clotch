// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "clotch",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "ClotchApp", targets: ["ClotchApp"]),
        .executable(name: "clotch", targets: ["clotch"]),
        .library(name: "ClotchCore", targets: ["ClotchCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.2.0"),
    ],
    targets: [
        .target(name: "ClotchCore"),
        .executableTarget(
            name: "ClotchApp",
            dependencies: [
                "ClotchCore",
                .product(name: "SwiftTerm", package: "SwiftTerm"),
            ]
        ),
        .executableTarget(
            name: "clotch",
            dependencies: ["ClotchCore"]
        ),
        // Plain executable check-runner: the Command Line Tools toolchain ships
        // neither XCTest nor swift-testing, so `swift run ClotchChecks` instead.
        .executableTarget(
            name: "ClotchChecks",
            dependencies: ["ClotchCore"],
            path: "Checks"
        ),
    ]
)
