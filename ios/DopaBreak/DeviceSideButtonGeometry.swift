import SwiftUI
import UIKit

/// 物理サイドボタンの縦位置を、画面の論理座標（pt・画面上端基準・セーフエリア無視）で返す。
struct DeviceSideButtonGeometry {
    /// 画面上端からボタン上端までのpt
    let top: CGFloat
    /// ボタンの長さpt
    let length: CGFloat
    /// Camera Control（右側面の下側のボタン）があるか。
    let hasCameraControl: Bool

    struct Spec {
        let topFraction: CGFloat
        let lengthFraction: CGFloat
        let hasCameraControl: Bool
    }

    private static let specsByIdentifier: [String: Spec] = [
        "iPhone11,2": Spec(topFraction: 0.2131, lengthFraction: 0.1260, hasCameraControl: false),
        "iPhone11,6": Spec(topFraction: 0.1932, lengthFraction: 0.1142, hasCameraControl: false),
        "iPhone11,4": Spec(topFraction: 0.1932, lengthFraction: 0.1142, hasCameraControl: false),
        "iPhone11,8": Spec(topFraction: 0.2041, lengthFraction: 0.1223, hasCameraControl: false),
        "iPhone12,1": Spec(topFraction: 0.2041, lengthFraction: 0.1223, hasCameraControl: false),
        "iPhone12,3": Spec(topFraction: 0.2321, lengthFraction: 0.1300, hasCameraControl: false),
        "iPhone12,5": Spec(topFraction: 0.2103, lengthFraction: 0.1178, hasCameraControl: false),
        "iPhone12,8": Spec(topFraction: 0.1167, lengthFraction: 0.1021, hasCameraControl: false),
        "iPhone13,1": Spec(topFraction: 0.2522, lengthFraction: 0.1424, hasCameraControl: false),
        "iPhone13,2": Spec(topFraction: 0.2428, lengthFraction: 0.1274, hasCameraControl: false),
        "iPhone13,3": Spec(topFraction: 0.2428, lengthFraction: 0.1274, hasCameraControl: false),
        "iPhone13,4": Spec(topFraction: 0.2682, lengthFraction: 0.1157, hasCameraControl: false),
        "iPhone14,4": Spec(topFraction: 0.2508, lengthFraction: 0.1452, hasCameraControl: false),
        "iPhone14,5": Spec(topFraction: 0.2861, lengthFraction: 0.1298, hasCameraControl: false),
        "iPhone14,2": Spec(topFraction: 0.2863, lengthFraction: 0.1295, hasCameraControl: false),
        "iPhone14,3": Spec(topFraction: 0.2600, lengthFraction: 0.1176, hasCameraControl: false),
        "iPhone14,6": Spec(topFraction: 0.1167, lengthFraction: 0.1021, hasCameraControl: false),
        "iPhone14,7": Spec(topFraction: 0.2854, lengthFraction: 0.1312, hasCameraControl: false),
        "iPhone14,8": Spec(topFraction: 0.2592, lengthFraction: 0.1192, hasCameraControl: false),
        "iPhone15,2": Spec(topFraction: 0.3062, lengthFraction: 0.1297, hasCameraControl: false),
        "iPhone15,3": Spec(topFraction: 0.2799, lengthFraction: 0.1186, hasCameraControl: false),
        "iPhone15,4": Spec(topFraction: 0.2924, lengthFraction: 0.1255, hasCameraControl: false),
        "iPhone15,5": Spec(topFraction: 0.2616, lengthFraction: 0.1147, hasCameraControl: false),
        "iPhone16,1": Spec(topFraction: 0.3158, lengthFraction: 0.1255, hasCameraControl: false),
        "iPhone16,2": Spec(topFraction: 0.2887, lengthFraction: 0.1147, hasCameraControl: false),
        "iPhone17,3": Spec(topFraction: 0.3063, lengthFraction: 0.1255, hasCameraControl: true),
        "iPhone17,4": Spec(topFraction: 0.2800, lengthFraction: 0.1147, hasCameraControl: true),
        "iPhone17,1": Spec(topFraction: 0.3044, lengthFraction: 0.1222, hasCameraControl: true),
        "iPhone17,2": Spec(topFraction: 0.2787, lengthFraction: 0.1118, hasCameraControl: true),
        "iPhone17,5": Spec(topFraction: 0.2854, lengthFraction: 0.1312, hasCameraControl: false),
        "iPhone18,3": Spec(topFraction: 0.3043, lengthFraction: 0.1222, hasCameraControl: true),
        "iPhone18,1": Spec(topFraction: 0.3043, lengthFraction: 0.1223, hasCameraControl: true),
        "iPhone18,2": Spec(topFraction: 0.2787, lengthFraction: 0.1118, hasCameraControl: true),
        "iPhone18,4": Spec(topFraction: 0.2904, lengthFraction: 0.1179, hasCameraControl: true),
        "iPhone18,5": Spec(topFraction: 0.2854, lengthFraction: 0.1312, hasCameraControl: false),
    ]

    /// 同じ論理サイズのうち最新モデルの割合。
    /// サイズフォールバックでは Camera Control の有無を推定しない。
    private static let specsByScreenSize: [CGSize: Spec] = [
        CGSize(width: 375, height: 812): Spec(topFraction: 0.2321, lengthFraction: 0.1300, hasCameraControl: false),
        CGSize(width: 414, height: 896): Spec(topFraction: 0.2103, lengthFraction: 0.1178, hasCameraControl: false),
        CGSize(width: 375, height: 667): Spec(topFraction: 0.1167, lengthFraction: 0.1021, hasCameraControl: false),
        CGSize(width: 360, height: 780): Spec(topFraction: 0.2508, lengthFraction: 0.1452, hasCameraControl: false),
        CGSize(width: 390, height: 844): Spec(topFraction: 0.2854, lengthFraction: 0.1312, hasCameraControl: false),
        CGSize(width: 428, height: 926): Spec(topFraction: 0.2592, lengthFraction: 0.1192, hasCameraControl: false),
        CGSize(width: 393, height: 852): Spec(topFraction: 0.3063, lengthFraction: 0.1255, hasCameraControl: false),
        CGSize(width: 430, height: 932): Spec(topFraction: 0.2800, lengthFraction: 0.1147, hasCameraControl: false),
        CGSize(width: 402, height: 874): Spec(topFraction: 0.3043, lengthFraction: 0.1223, hasCameraControl: false),
        CGSize(width: 440, height: 956): Spec(topFraction: 0.2787, lengthFraction: 0.1118, hasCameraControl: false),
        CGSize(width: 420, height: 912): Spec(topFraction: 0.2904, lengthFraction: 0.1179, hasCameraControl: false),
    ]

    private static let fallbackSpec = Spec(
        topFraction: 0.2793,
        lengthFraction: 0.1223,
        hasCameraControl: false
    )

    static func current() -> DeviceSideButtonGeometry {
        let environment = ProcessInfo.processInfo.environment
        return current(
            environment: environment,
            screenBounds: UIScreen.main.bounds,
            machineIdentifier: machineIdentifier
        )
    }

    static func current(
        environment: [String: String],
        screenBounds: CGRect,
        machineIdentifier: String
    ) -> DeviceSideButtonGeometry {
        let identifier = environment["SIMULATOR_MODEL_IDENTIFIER"] ?? machineIdentifier
        let width = min(screenBounds.width, screenBounds.height)
        let height = max(screenBounds.width, screenBounds.height)
        return resolve(
            modelIdentifier: identifier,
            screenSize: CGSize(width: width, height: height),
            screenHeight: height
        )
    }

    static func resolve(
        modelIdentifier: String,
        screenSize: CGSize,
        screenHeight: CGFloat
    ) -> DeviceSideButtonGeometry {
        let spec = specsByIdentifier[modelIdentifier]
            ?? specsByScreenSize[screenSize]
            ?? fallbackSpec
        return DeviceSideButtonGeometry(
            top: spec.topFraction * screenHeight,
            length: spec.lengthFraction * screenHeight,
            hasCameraControl: specsByIdentifier[modelIdentifier]?.hasCameraControl ?? false
        )
    }

    private static var machineIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }
}
