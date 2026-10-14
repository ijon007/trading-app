// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Updraft",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [.library(name: "Updraft", targets: ["Updraft"])],
    targets: [.target(name: "Updraft", resources: [.process("Resources")])]
)
