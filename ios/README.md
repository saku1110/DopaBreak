# DopaBreak iOS

Regenerate: `xcodegen generate`
Build: `xcodebuild -project DopaBreak.xcodeproj -scheme DopaBreak -destination 'generic/platform=iOS Simulator' -derivedDataPath .deriveddata CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" build`
Test core package: `cd Packages/DopaBreakCore && swift test`
Change bundle prefix in one place: `Configs/Shared.xcconfig` (`DOPABREAK_BUNDLE_PREFIX`).
FamilyControls requires a real device.
The distribution entitlement is applied for per `docs/10_familycontrols_entitlement.md`.
