#import "FlutterLyricPlugin.h"
#import <flutter_lyric/flutter_lyric-Swift.h>

@implementation FlutterLyricPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterLyricPlugin registerWithRegistrar:registrar];
}
@end
