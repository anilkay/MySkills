---
name: "dotnet-single-file-release"
description: "Set up or cut a GitHub release of a .NET desktop/CLI app as a self-contained single-file exe built by GitHub Actions on v* tags, plus a safe local tag script."
---

# .NET self-contained single-file release (GitHub Actions + tag script)

Use when a .NET app (WinForms, WPF, Avalonia, console) should be downloadable from GitHub Releases without the user installing the .NET runtime. For a macOS `.app` bundle, use the macos-app-bundle skill instead; this skill covers the plain exe/binary.

## Ground rules
- Pushing a tag publishes a public release. Never push a tag, or run the release script for real, without the user's explicit go-ahead for that version.
- Ask before adding or changing workflow files; show the diff first.
- Reply in the user's language.

## 1. Verify the publish command locally first
```
dotnet publish <App>/<App>.csproj -c Release -r win-x64 --self-contained true \
  -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true \
  -p:EnableCompressionInSingleFile=true -p:DebugType=none -o publish
```
- Other RIDs: `linux-x64`, `osx-arm64`, `win-arm64`. WinForms/WPF are Windows only.
- Expect ~50 MB for a WinForms app. Do NOT enable trimming for WinForms/WPF (unsupported); for others test trimming separately.
- Run the produced exe once from a clean folder to confirm it starts (reflection-heavy libs can break in single-file).

## 2. Workflow: `.github/workflows/release.yml`
```yaml
name: Release
on:
  push:
    tags: ['v*']
permissions:
  contents: write
  id-token: write        # only if using attestation
  attestations: write    # only if using attestation
jobs:
  release:
    runs-on: windows-latest   # ubuntu-latest for non-Windows-only apps
    steps:
      - uses: actions/checkout@<full-commit-sha>      # pin by SHA, comment the version
      - uses: actions/setup-dotnet@<full-commit-sha>
        with: { dotnet-version: '10.0.x' }
      - name: Publish
        run: >
          dotnet publish <App>/<App>.csproj -c Release -r win-x64 --self-contained true
          -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true
          -p:EnableCompressionInSingleFile=true -p:DebugType=none -o publish
      - name: Zip and checksum
        shell: pwsh
        env: { TAG: '${{ github.ref_name }}' }   # never inline ${{ }} into scripts
        run: |
          $zip = "<App>-$env:TAG-win-x64.zip"
          Compress-Archive publish/<App>.exe $zip
          (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower() + "  $zip" | Out-File SHA256SUMS -Encoding ascii
      - uses: actions/attest-build-provenance@<full-commit-sha>   # optional, free on public repos
        with: { subject-path: '*.zip' }
      - name: Create release
        shell: pwsh
        env: { GH_TOKEN: '${{ github.token }}', TAG: '${{ github.ref_name }}' }
        run: gh release create $env:TAG "<App>-$env:TAG-win-x64.zip" SHA256SUMS --title $env:TAG --generate-notes
```
Notes: use `gh release create` instead of a third-party release action; keep permissions minimal; for multiple RIDs use a matrix job that uploads artifacts and a final job that creates the release.

## 3. Local tag script (`release.ps1` at repo root)
The script only creates and pushes an annotated tag; CI does the rest. It must refuse to run unless all checks pass:
- normalize `1.2.3` to `v1.2.3`; validate `^v\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?$`
- current branch is the default branch; `git status --porcelain` is empty
- `git fetch origin <default> --tags`; local HEAD equals `origin/<default>`
- tag exists neither locally nor on origin (`git ls-remote --tags origin refs/tags/<tag>`)
- print the previous tag (`git describe --tags --abbrev=0`) and short SHA
- use `[CmdletBinding(SupportsShouldProcess)]` so `-WhatIf` is a dry run
- wrap git in a helper that throws on non-zero exit; `$ErrorActionPreference = 'Stop'`
- after pushing, print the Actions run URL and the release URL

A bash equivalent (`release.sh`) follows the same checks with `set -euo pipefail`.

## 4. Cutting a release
1. Confirm the version with the user and that they want it published now.
2. Run the script with `-WhatIf` first, then for real.
3. Watch the workflow run; when it finishes, check the release page has the zip (and SHA256SUMS), download it and confirm it launches.
4. If the build fails, fix on the default branch, delete the tag locally and remotely only with user approval, and re-tag.

## Hardening checklist (mention gaps to the user)
- Actions pinned to commit SHAs; `${{ }}` values passed via `env:`
- SHA256SUMS and build provenance attestation attached
- `RestorePackagesWithLockFile` + committed `packages.lock.json` for reproducible restores
- Tag protection ruleset for `v*` on repos with several writers
- Authenticode signing (e.g. SignPath for OSS) to avoid SmartScreen warnings
- README: tell users to extract the exe into its own empty folder (reduces DLL planting risk)