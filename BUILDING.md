# Building OpenKey

This guide covers building and testing the jetaudio fork of OpenKey on macOS and Windows.
Vietnamese instructions for macOS are in [macOS_Build.md](macOS_Build.md).

## macOS

### Requirements

- macOS with **full Xcode**. The fork is tested with Xcode 27. The deployment target is macOS 12.0.
- Network access for the first build, which downloads librime and the Rime data.
- The Command Line Tools are enough to run the regression tests. The app itself needs full Xcode.

### Build a universal DMG

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash scripts/build-macos-dmg.sh
```

The script does the following:

1. Builds the `OpenKey` scheme in Release for `arm64` and `x86_64`.
2. Checks that the storyboard, `librime.1.dylib` and the compiled Pinyin dictionary are embedded, and that both architectures are present.
3. Signs the app ad hoc and verifies the signature and `Info.plist`.
4. Writes three files to `dist/`:
   - `OpenKey-<version>-<commit>-universal.dmg`
   - its `.sha256` checksum
   - a `-BUILD-INFO.txt` file that records the source commit and Xcode version

The result is **not notarized**.

### Build from Xcode

Open `Sources/OpenKey/macOS/OpenKey.xcodeproj`, select the **OpenKey** scheme and choose **Product → Run** or **Product → Archive**. The **Embed Rime** build phase runs `scripts/fetch-rime.sh` automatically.

### Rime (Chinese input) dependencies

`scripts/fetch-rime.sh` prepares everything the Chinese mode needs in `Sources/OpenKey/macOS/ThirdParty/Rime`. Git ignores that folder.

| Component | Pinned version | License |
| --- | --- | --- |
| librime | 1.17.0, universal macOS build | BSD 3-Clause |
| rime-prelude | commit `082425e` | LGPL-3.0 |
| rime-essay | commit `054920d` | LGPL-3.0 |
| rime-pinyin-simp | commit `0c6861e` | Apache-2.0 |

Each download is checked against a SHA-256 hash in the script, and the `pinyin_simp` dictionary is precompiled. A stamp file skips the work when nothing has changed. To force a refresh, delete the folder.

OpenKey's own Rime configuration is in `Sources/OpenKey/macOS/Rime/default.custom.yaml`.

## Windows

### Requirements

- Visual Studio 2022 with the **Desktop development with C++** workload, which includes MSBuild and the Windows SDK.

### Build

Open `Sources/OpenKey/win32/OpenKey/OpenKey.sln` in Visual Studio and build **Release** for **Win32** or **x64**.

To build from a Developer PowerShell, as CI does:

```powershell
foreach ($arch in 'x86', 'x64') {
  $platform = if ($arch -eq 'x86') { 'Win32' } else { 'x64' }
  foreach ($project in 'OpenKey', 'OpenKeyUpdate') {
    msbuild "Sources\OpenKey\win32\OpenKey\$project\$project.vcxproj" -m -target:Rebuild `
      -p:Configuration=Release "-p:Platform=$platform" `
      "-p:OutDir=$PWD\ArtifactOutput\$arch\" "-p:IntDir=$PWD\build\obj\$project\$arch\"
  }
}
```

The outputs are `OpenKey32.exe` or `OpenKey64.exe`, plus `OpenKeyUpdate.exe`, in `ArtifactOutput\<arch>\`.

## Tests

| Script | What it covers | Requires |
| --- | --- | --- |
| `scripts/test-engine.sh` | Typing engine (tone placement in both orthographies), code-table conversion, smart-switch preferences. Runs under ASan/UBSan. | Command Line Tools |
| `scripts/test-macos-events.sh` | Event tap callback, key sending, Spotlight, Fn shortcuts, Chinese mode and tap lifecycle. All system calls are mocked. | Command Line Tools |
| `scripts/test-rime.sh` | Pinyin input, candidates, learning and forgetting phrases through librime. | Command Line Tools, network on first run |
| `scripts/test-macos-ui.sh <app> <png>` | Compiled storyboard outlets, layout geometry and the Fn action. Renders the preferences window to a PNG. | A built app and a GUI session |

On Windows, CI also compiles `tests/engine_regression.cpp` with MSVC (`cl /std:c++14 /utf-8`) and runs it with Windows key codes.

## Continuous integration

| Workflow | Trigger | Output |
| --- | --- | --- |
| [Build macOS DMG](.github/workflows/macos-dmg.yml) | Pushes to `master` that touch the engine, macOS sources, tests or scripts. Can also be started manually. | Runs the engine, Rime and event tests, then builds and verifies the universal DMG. Artifact: **OpenKey-macos-universal** |
| [MSBuild](.github/workflows/msbuild.yml) | Pushes and pull requests to `master`. Can also be started manually. | Runs the engine tests with MSVC, then builds the x86 and x64 app and updater and checks each PE machine type. Artifact: **OpenKey**, with a build-provenance attestation |
