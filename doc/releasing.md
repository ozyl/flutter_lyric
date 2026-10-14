# Release checks

Keep `pubspec.yaml`, the README installation constraint, the newest CHANGELOG
entry and the example's path dependency lock version in sync. Choose versions
using [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html): features
that preserve the published API increment MINOR; fixes increment PATCH;
incompatible public API changes increment MAJOR. Compare against the actual
[published versions](https://pub.dev/packages/flutter_lyric/versions).

Run package and example analysis/tests on the configured Flutter SDK. CI also
checks the library in isolation on Flutter 2.0.6 / Dart 2.12.3, so the newer
example dependencies do not raise the library minimum.

```sh
flutter pub get --no-example
flutter analyze --no-pub
flutter test --no-pub
cd example
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
cd ..
```

After committing the release changes, score a clean copy because pana can
modify its input. Keep API documentation generation enabled; disabling it
omits documentation coverage points from the reported maximum.

```sh
dart pub global activate pana
release_dir=$(mktemp -d)
git archive HEAD | tar -x -C "$release_dir"
dart pub global run pana --exit-code-threshold 0 "$release_dir"
cd "$release_dir"
flutter pub publish --dry-run
```

The [pub.dev scoring guide](https://pub.dev/help/scoring) describes the current
criteria. Require full points in every category, including API documentation,
static analysis, platform/toolchain support and current dependencies. A local
report checks release readiness; pub.dev runs its own analysis after upload.
`.pubignore` excludes local SDK/editor configuration and generated files.

Publish only as part of the actual release. Then create an
[annotated Git tag](https://git-scm.com/docs/git-tag) matching the uploaded
version, for example `git tag -a v4.1.0 -m "v4.1.0"`. Release preparation and
ordinary commits do not create tags. Commit messages follow
[Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/).
