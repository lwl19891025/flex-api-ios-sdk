xcodebuild clean archive \
-scheme CybersourceFlexSDK \
-project flex-api-ios-sdk.xcodeproj \
-destination="iOS" \
-archivePath archives/CybersourceFlexSDK-iphoneos.xcarchive \
-sdk iphoneos SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES

xcodebuild archive \
-scheme CybersourceFlexSDK \
-project flex-api-ios-sdk.xcodeproj \
-destination="iOS Simulator" \
-archivePath archives/CybersourceFlexSDK-iphonesimulator.xcarchive \
-sdk iphonesimulator SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES

xcodebuild -create-xcframework \
-archive archives/CybersourceFlexSDK-iphoneos.xcarchive \
-framework CybersourceFlexSDK.framework \
-archive archives/CybersourceFlexSDK-iphonesimulator.xcarchive \
-framework CybersourceFlexSDK.framework \
-output archives/CybersourceFlexSDK.xcframework