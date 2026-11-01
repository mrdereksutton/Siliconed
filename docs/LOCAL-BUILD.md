# Local development build

## Verified baseline

On November 1, 2026, the unmodified Siliconed 0.17 app source compiled successfully on the development Mac using Apple Swift 6.4 and the macOS 26.5 SDK already installed with Command Line Tools. The rendering-engine target also compiled. No model downloads or image-generation runs were needed for these checks.

Run this from the repository root on that Mac:

```sh
env \
  CLANG_MODULE_CACHE_PATH="$PWD/.build/sdk26/ModuleCache" \
  SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/sdk26/ModuleCache" \
  swift build \
    --build-system native \
    --jobs 2 \
    --sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk \
    --scratch-path .build/sdk26 \
    --cache-path .build/cache \
    --config-path .build/config \
    --security-path .build/security \
    --manifest-cache local \
    --product SiliconedApp
```

The two compiler jobs keep the initial build's resource use bounded on the 16 GB Mac. Build caches stay under `.build`, which is ignored by Git.

## Why these options are used here

The local Swift 6.4 default build backend fails during initialization with `Unknown error parsing property list`. The native backend reaches compilation. With this Mac's default macOS 27 SDK, compiling the app then fails because the `SwiftUIMacros.StateMacro` compiler plugin is unavailable. Selecting the installed macOS 26.5 SDK resolves that failure. These are local build-tool compatibility choices; the app's source and rendering behavior remain unchanged.

## Next setup work

The executable has compiled; a separately identified development app bundle has not been packaged or launched yet. The upstream packaging script calls `xcstringstool`, which is absent from this Command Line Tools installation. The development packaging path needs to account for localization resources, a distinct app identity, and separate preferences and generated-image storage before launch.

Model files should be reused through a deliberate read path rather than downloaded again as part of development setup. The installed release and its data remain the reference for comparison.
