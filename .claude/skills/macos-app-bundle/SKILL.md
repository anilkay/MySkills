---
name: macos-app-bundle
description: Package a .NET desktop app (Avalonia, or any self-contained `dotnet publish -r osx-*` output) as a double-clickable macOS .app bundle with icon, Info.plist, microphone/camera permission text and an ad-hoc signature, zip it for GitHub Releases, and check it in CI on a macOS runner. Use when the user wants a Mac build that opens from Finder instead of Terminal, a .app/.icns/Info.plist, Apple Silicon or Intel Mac release assets, or hits codesign errors like "code object is not signed at all ... In subcomponent: *.dll".
---

# macOS .app bundle for a .NET app

Turns a `dotnet publish --runtime osx-arm64|osx-x64 --self-contained` folder into `<Name>.app`, zipped
for a release. Proven on PodcastRecorder (Avalonia, .NET 10): built, verified and opened on the
`macos-latest` GitHub runner. No Apple Developer account needed; the result is ad-hoc signed, not
notarized.

## Files to add to the project

Copy the templates next to this skill into the app project, e.g. `src/<App>/macOS/`:

- `templates/package-app.sh`: fill in `APP_NAME`, `EXECUTABLE` and the icon paths at the top.
- `templates/Info.plist`: fill in name, bundle id (reverse DNS the user owns, e.g. `io.github.<user>.<App>`),
  executable, and the usage texts the app needs (`NSMicrophoneUsageDescription`, `NSCameraUsageDescription`…).
  The version placeholders are replaced by the script with `plutil`.

Mark the script executable in git (`git update-index --chmod=+x`) and keep it LF. With
`core.autocrlf=true` on Windows the index stays LF; check with `git ls-files --eol`.

## Bundle layout

```
<Name>.app/Contents/
  Info.plist
  MacOS/            the whole publish output, including runtimes/ and satellite folders
  Resources/AppIcon.icns
```

`CFBundleExecutable` is the apphost name (the project's AssemblyName, no extension).

## Signing: the lessons

- Apple Silicon refuses to run unsigned code, so sign ad hoc: `codesign --force --sign - --timestamp=none`.
- **macOS treats every file in `Contents/MacOS` as code, the .NET `.dll` files too.**
  `codesign --deep` on the bundle fails with
  `code object is not signed at all  In subcomponent: .../System.Web.dll`.
  Sign every file under `Contents/MacOS` except the main executable first (a non-Mach-O file keeps
  its signature in extended attributes), then sign the bundle, which signs the main executable.
- Never sign the main executable on its own inside the bundle; that triggers the same error.
- Finish with `codesign --verify --strict --verbose=2 <app>`, which should print "valid on disk" and
  "satisfies its Designated Requirement".
- Zip with `ditto -c -k --keepParent <app> <zip>`. ditto keeps the extended-attribute signatures;
  `zip -r` and `tar` from other tools may not.

## Icon

`iconutil -c icns <dir>.iconset` needs `icon_16x16.png` … `icon_512x512@2x.png` (16-1024 px).
Use hand-tuned small PNGs where the project has them and render 512/1024 from the SVG with
`rsvg-convert` (`brew install librsvg`, a few seconds on the runner).

## App behaviour when opened from Finder

A Finder or Dock launch gets only the system `PATH` (`/usr/bin:/bin:/usr/sbin:/sbin`), not the shell's:

- Command-line tools from Homebrew (`ffmpeg`, …) are not found. Look in `/opt/homebrew/bin` (Apple
  Silicon) and `/usr/local/bin` (Intel) before falling back to the bare name.
- Native libraries loaded by name (`libmp3lame`) likewise: try `/opt/homebrew/lib/...` and
  `/usr/local/lib/...` explicitly.
- The working directory is `/`; resolve files from `AppContext.BaseDirectory`, never relative paths.
- Avalonia: set `Name="<Display Name>"` on the root `Application` in App.axaml for the menu-bar name.

## CI

In the macOS job of the build workflow, package on every PR and open it the way a double click does:

```yaml
- name: Package the macOS app and open it
  if: runner.os == 'macOS'
  run: |
    brew install librsvg
    dotnet publish src/<App> --configuration Release --runtime osx-arm64 --self-contained --output publish/<App>
    bash src/<App>/macOS/package-app.sh publish/<App> 0.0.0 publish
    ditto -c -k --keepParent "publish/<Name>.app" <App>-osx-arm64.zip
    open "publish/<Name>.app"
    sleep 15
    pgrep -x <Executable>        # still running 15 s later
    pkill -x <Executable>
- uses: actions/upload-artifact@v6   # lets the user try it on a Mac before a release
  if: runner.os == 'macOS'
  with:
    name: <App>-osx-arm64-app
    path: <App>-osx-arm64.zip
```

In the release workflow, a matrix entry per Mac architecture (`osx-arm64` and `osx-x64`, both on
`macos-latest`; cross-publishing to x64 works) runs the same script and uploads
`<App>-<version>-<rid>.zip`. Linux keeps its tar.gz.

## Tell the user

- What CI cannot test: downloading the zip, Gatekeeper's first-launch block, the permission prompts.
  Point them to the CI artifact to try on their own Mac.
- Ad hoc means not notarized: a downloaded copy must be allowed once in System Settings › Privacy &
  Security › "Open Anyway", or with `xattr -dr com.apple.quarantine "/Applications/<Name>.app"`.
  Put this in the README. Real signing and notarization need an Apple Developer ID ($99/year),
  `codesign --options runtime` with entitlements, and `xcrun notarytool`.
- The permission prompt (microphone etc.) shows the Info.plist usage text; macOS remembers the
  choice per bundle id, under System Settings › Privacy & Security.
