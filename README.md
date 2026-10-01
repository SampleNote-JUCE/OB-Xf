# About

OB-Xf is a continuation of the last open source version of OB-Xd by [2DaT](https://github.com/2DaT/Obxd) and later
[discoDSP](https://github.com/reales/OB-Xd), bringing together several efforts going on in the audio space and
combining them inside the Surge Synth Team infrastructure.

The synth is currently in a beta phase, with a few features still under development, but the plugin is feature stable and working rather well, we believe.

# Installation

We provide installers (signed DMG for macOS, EXE for Windows x64/ARM64/ARM64EC, DEB for Linux x86_64 built on Ubuntu 20) [here](https://github.com/surge-synthesizer/OB-Xf/releases/tag/Nightly). See that page for installation instructions.

# Compatibility with OB-Xd

Patches and banks created by OB-Xd **are** compatible with OB-Xf, using the "Import OB-Xd Bank..." option in the patch browser, or by simply drag-and-dropping OB-Xd FXP/FXB files onto OB-Xf's interface.
This functionality was introduced in v1.1 update.

Fidelity of conversion is retained in all cases except one. This is due to the fact that OB-Xd has an offset of 12 semitones when all coarse tuning controls are set to 0 semitones - so middle C produces ~464 Hz instead of the expected ~232 Hz. OB-Xf has fixed this reference pitch, and compensates for the discrepancy by increasing the Transpose parameter by 12 semitones. If Transpose parameter was already at maximum, both oscillators are pitched up by 12 semitones. If either of the oscillator pitch controls don't allow for an increase of 12 semitones, the imported patch will sound one octave lower than in OB-Xd.

# Building

Using CMake:

```bash
git submodule update --init --recursive
cmake -B Builds/Release -DCMAKE_BUILD_TYPE=Release .
cmake --build Builds/Release --config Release --target obxf-staged
```

This will build supported plugin formats and place them in builds/Release/obxf_products. If you self-build, you are responsible for installing the assets from assets/installer in the appropriate location. When running the plugin or standalone, you will see where OB-Xf attempted to look for assets, if you get it wrong.

If you are on a unix system we provide the following convenience to install the factory assets after a build

```bash
cmake --install Builds/Release
```

You may need a sudo. Like the build, this will use the `CMAKE_INSTALL_PREFIX` for the shared location

## Orange Pi 5 / DietPi (VST3 only)

From a Git checkout on the Orange Pi 5 running 64-bit DietPi, run:

```bash
bash scripts/build_orangepi5.sh
```

The script installs build dependencies using apt (as root or through sudo), downloads
the pinned recursive submodules, and builds only the VST3. It requires GCC/G++ 12 or
newer and CMake 3.22 or newer; older DietPi installations may need a newer toolchain
or OS release. It uses `-O3 -DNDEBUG -mcpu=cortex-a76.cortex-a55`, without fast-math
or LTO, and defaults to two parallel jobs for an 8 GB board, including JUCE helper
compilation. Lower this with `--jobs 1` if memory is tight.

The script can be invoked from any directory. Use `--build-dir PATH` to choose a
different output directory (relative to your current directory), `--skip-deps` to
skip apt after dependencies are installed, and `--help` for usage. For example:

```bash
bash scripts/build_orangepi5.sh --skip-deps --jobs 2
```

Rerunning uses the existing build incrementally. The default bundle is
`build/orangepi5-release/OB-Xf_artefacts/Release/VST3/OB-Xf.vst3`.
The script leaves plugin and factory asset installation to you. To install for your
user, run these commands from the repository root as the user who runs the plugin host
(adjust the bundle path if you used `--build-dir`):

```bash
mkdir -p "$HOME/.vst3" "${XDG_DATA_HOME:-$HOME/.local/share}/Surge Synth Team/OB-Xf"
cp -a build/orangepi5-release/OB-Xf_artefacts/Release/VST3/OB-Xf.vst3 "$HOME/.vst3/"
cp -a "assets/installer/Surge Synth Team/OB-Xf/." "${XDG_DATA_HOME:-$HOME/.local/share}/Surge Synth Team/OB-Xf/"
```

Copy the whole `.vst3` bundle. Use an ARM64 Linux VST3 host and rescan its plugins.
On the board, check the binary and runtime dependencies with:

```bash
file build/orangepi5-release/OB-Xf_artefacts/Release/VST3/OB-Xf.vst3/Contents/aarch64-linux/OB-Xf.so
ldd build/orangepi5-release/OB-Xf_artefacts/Release/VST3/OB-Xf.vst3/Contents/aarch64-linux/OB-Xf.so
```

Confirm the binary is AArch64, no dependencies are missing, and the host can open
the editor, load factory patches, and play notes through MIDI. Building can run
over SSH without a desktop; displaying the plugin editor requires a graphical session.

## iPad / iOS target (work in progress)

iOS support is being added incrementally. The initial CMake wiring enables iOS-safe formats (`AUv3`, `Standalone`) and disables desktop-only packaging steps.

OB-Xf is GPLv3 software. We do not distribute an iOS build through Apple's App Store because Apple and the FSF disagree on whether App Store distribution is compatible with GPLv3 terms. As a result, iOS support is self-build only.

The current iOS CMake setup targets iPad (`TARGETED_DEVICE_FAMILY=2`).

A starting point for generating an Xcode iOS project is:

```bash
cmake -B Builds/iOS -G Xcode -DCMAKE_SYSTEM_NAME=iOS -DOBXF_IOS_DISABLE_CODESIGN=ON .
cmake --build Builds/iOS --config Release
```

If you want to sign for device install, set your team ID and disable the no-signing default:

```bash
cmake -B Builds/iOS -G Xcode -DCMAKE_SYSTEM_NAME=iOS -DOBXF_IOS_DISABLE_CODESIGN=OFF -DOBXF_IOS_DEVELOPMENT_TEAM=YOURTEAMID .
```

Packaging and asset installation for iOS are not complete yet.
# Copyright

This repository and the source code is under GPL3 license. OB-Xf is and always will be free in all contexts and for all uses, with the source code available and modifiable, and the software usable in any context, free or commercial.
