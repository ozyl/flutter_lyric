#import "FlutterLyricPlugin.h"
#if __has_include(<flutter_lyric/flutter_lyric-Swift.h>)
#import <flutter_lyric/flutter_lyric-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "flutter_lyric-Swift.h"
#endif

@implementation FlutterLyricPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterLyricPlugin registerWithRegistrar:registrar];
}
@end
