// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LifeCoach",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [.library(name: "LifeCoachCore", targets: ["LifeCoachCore"])],
    targets: [
        .target(name: "LifeCoachCore"),
        .testTarget(name: "LifeCoachCoreTests", dependencies: ["LifeCoachCore"]),
    ]
)
