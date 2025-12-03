## [3.0.1]
* feat: Changed style management—now pass styles via the `LyricView.style` parameter instead of using `LyricController.setStyle()`
* perf: Added `LyricStyle.compareTo()` for smarter/faster detection of when relayout or repaint is needed on style changes
* fix: In `LyricStyle.copyWith()`, renamed the parameter `crossAxisAlignment` to the correct `contentAlignment`
* breaking: Removed `LyricController.styleNotifier` and the `setStyle()` method
* fix: Fixed an issue when switching lyrics

## [3.0.0+1]
* update plugin config

## [3.0.0]
* breaking: Rebuilt `LyricView` and the scrolling/highlight mixins so everything is driven by a single `LyricController`
* feat: Added translation & word-by-word rendering, touch scrubbing, anchor selection, and tap callbacks
* feat: Extended `LyricStyle` with gradient highlights, fade ranges, and scroll-duration mapping for deeper customization
* docs: Refreshed the README with a 3.0.0 migration guide

## [2.0.4+6]
* Fix animation before first line starts
## [2.0.4+5]
* Avoid Warning messages
## [2.0.4+4]
* fix:position has error on init.
## [2.0.4+3]
* fix:position not work on init. has error,please use [2.0.4+4]
## [2.0.4+2]
* fix package not showing support for Android, iOS, Windows, Linux & macOS on pub.dev.
## [2.0.4+1]
* merged pull#18 [Remove redundant configuration. ](https://github.com/ozyl/flutter_lyric/pull/18)
## [2.0.4]
* [Support setting gradient direction](https://github.com/ozyl/flutter_lyric/issues/14)
## [2.0.3]
* add empty status builder
* fix size
## [2.0.2+4]
* fix:highlight NPE
## [2.0.2+3]
* fix:padding lead to overflow clipping
## [2.0.2+2]
* pub score
## [2.0.2+1]
* fix location always on last
## [2.0.2]
* highlight(enhanced&normal)
## [2.0.1+2~2.0.1+6]
* modify pub config
## [2.0.1+1]
* fix safari load failed
## [2.0.1]
* more smooth
## [2.0.0+1]
* docs: Update CHANGELOG.md,README.md
## [2.0.0]
* sliding inertia.custom UI,Parse
## [0.0.1~1.0.2]
* show lyric