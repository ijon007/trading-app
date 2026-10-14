// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Aurum",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [.library(name: "Aurum", targets: ["Aurum"])],
    targets: [.target(name: "Aurum")]
)
