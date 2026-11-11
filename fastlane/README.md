fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Android

### android listing

```sh
[bundle exec] fastlane android listing
```

Upload listing text + feature graphic to Play (no binary/screenshots)

### android validate

```sh
[bundle exec] fastlane android validate
```

Validate the listing upload without publishing (dry run)

### android screenshots

```sh
[bundle exec] fastlane android screenshots
```

Upload dark-theme phone + tablet screenshots to Play

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
