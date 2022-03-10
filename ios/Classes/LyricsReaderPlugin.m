#import "LyricsReaderPlugin.h"
#if __has_include(<lyrics_reader/lyrics_reader-Swift.h>)
#import <lyrics_reader/lyrics_reader-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "lyrics_reader-Swift.h"
#endif

@implementation LyricsReaderPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftLyricsReaderPlugin registerWithRegistrar:registrar];
}
@end
