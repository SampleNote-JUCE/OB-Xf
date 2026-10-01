#!/usr/bin/env bash
# Native DietPi/ARM64 build for the Orange Pi 5 (Cortex-A76 + Cortex-A55).
set -euo pipefail

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

trap 'printf "Build script failed at line %s. See the error above.\n" "$LINENO" >&2' ERR

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
build_dir="$repo_dir/build/orangepi5-release"
jobs=2
skip_deps=false

usage() {
    cat <<'EOF'
Usage: build_orangepi5.sh [options]

Install build dependencies and build only the ARM64 OB-Xf VST3 on DietPi.
Run directly on the Orange Pi 5. Plugin and factory assets are not installed.

  --jobs N          Parallel jobs, including JUCE helper builds (default: 2)
  --build-dir PATH  Build directory (default: <repo>/build/orangepi5-release)
                    Relative paths are resolved from the current directory.
  --skip-deps       Skip apt update/install; still initialize Git submodules
  --help            Show this help

Requires 64-bit ARM Linux, apt, GCC/G++ >= 12, and CMake >= 3.22.
EOF
}

while (($#)); do
    case "$1" in
        --jobs)
            (($# >= 2)) || die '--jobs requires a positive integer'
            [[ "$2" =~ ^[1-9][0-9]*$ ]] || die '--jobs requires a positive integer'
            jobs="$2"
            shift 2
            ;;
        --build-dir)
            (($# >= 2)) || die '--build-dir requires a path'
            [[ -n "$2" && "$2" != --* ]] || die '--build-dir requires a path'
            build_dir="$2"
            shift 2
            ;;
        --skip-deps) skip_deps=true; shift ;;
        --help) usage; exit 0 ;;
        *) die "Unknown option: $1 (see --help)" ;;
    esac
done

[[ "$(uname -s)" == Linux && "$(uname -m)" == aarch64 ]] ||
    die 'Run this script on the Orange Pi 5 with 64-bit ARM Linux (aarch64).'
[[ "$(getconf LONG_BIT)" == 64 ]] || die 'A 64-bit userspace is required.'
command -v apt-get >/dev/null || die 'apt-get is required; this script targets DietPi/Debian.'
[[ -f "$repo_dir/CMakeLists.txt" && -f "$repo_dir/.gitmodules" ]] ||
    die 'Keep this script inside the repository scripts directory.'

if ! "$skip_deps"; then
    privilege=()
    if ((EUID != 0)); then
        command -v sudo >/dev/null || die 'Install sudo or run as root to install build dependencies.'
        privilege=(sudo)
    fi
    packages=(
        build-essential cmake ninja-build pkg-config git ca-certificates
        libasound2-dev libfontconfig1-dev libfreetype6-dev
        libx11-dev libxcomposite-dev libxcursor-dev libxext-dev
        libxinerama-dev libxrandr-dev libxrender-dev
    )
    "${privilege[@]}" apt-get update
    "${privilege[@]}" apt-get install -y --no-install-recommends "${packages[@]}"
fi

for tool in git cmake ninja pkg-config gcc g++; do
    command -v "$tool" >/dev/null || die "Missing $tool; run without --skip-deps to install dependencies."
done

cmake_version="$(cmake --version)"
if [[ "$cmake_version" =~ cmake\ version\ ([0-9]+)\.([0-9]+) ]]; then
    cmake_major="${BASH_REMATCH[1]}"
    cmake_minor="${BASH_REMATCH[2]}"
    ((cmake_major > 3 || (cmake_major == 3 && cmake_minor >= 22))) ||
        die 'CMake >= 3.22 is required. Use a newer DietPi/Debian release or install a newer CMake, then rerun.'
else
    die 'Could not determine the CMake version.'
fi

for compiler in gcc g++; do
    compiler_version="$("$compiler" -dumpfullversion -dumpversion)"
    compiler_major="${compiler_version%%.*}"
    [[ "$compiler_major" =~ ^[0-9]+$ ]] || die "Could not determine the $compiler version."
    ((compiler_major >= 12)) ||
        die "$compiler >= 12 is required. Install a newer default GCC/G++ toolchain or use a newer DietPi/Debian release, then rerun."
done

cpu_flag='-mcpu=cortex-a76.cortex-a55'
printf 'int main(void) { return 0; }\n' |
    gcc "$cpu_flag" -x c -c -o /dev/null - || die "gcc does not support $cpu_flag."
printf 'int main() { return 0; }\n' |
    g++ "$cpu_flag" -std=c++20 -x c++ -c -o /dev/null - ||
    die "g++ does not support C++20 and $cpu_flag."

git -C "$repo_dir" rev-parse --show-toplevel >/dev/null ||
    die 'Use a Git checkout of this repository so pinned submodules can be downloaded.'
git -C "$repo_dir" submodule update --init --recursive

# CMake invokes a nested build for juceaide during configuration. Bound that too.
export CMAKE_BUILD_PARALLEL_LEVEL="$jobs"
mkdir -p -- "$build_dir"
build_dir="$(cd -- "$build_dir" && pwd)"
[[ "$build_dir" != "$repo_dir" ]] || die 'Choose a build directory outside the repository root.'
release_flags="-O3 -DNDEBUG $cpu_flag"

printf 'Building VST3 in %s with %s parallel jobs\n' "$build_dir" "$jobs"
cmake -S "$repo_dir" -B "$build_dir" -G Ninja \
    -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++ \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_FLAGS= -DCMAKE_CXX_FLAGS= \
    "-DCMAKE_C_FLAGS_RELEASE=$release_flags" \
    "-DCMAKE_CXX_FLAGS_RELEASE=$release_flags" \
    -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=OFF \
    -DCOPY_PLUGIN_AFTER_BUILD=OFF \
    -DOBXF_BUILD_PYTHON_BINDINGS=OFF -DOBXF_BUILD_TESTS=OFF \
    -DENABLE_ASAN=OFF -DENABLE_TSAN=OFF
cmake --build "$build_dir" --config Release --target OB-Xf_VST3 --parallel "$jobs"

bundle="$build_dir/OB-Xf_artefacts/Release/VST3/OB-Xf.vst3"
[[ -d "$bundle" ]] || die "Build finished but the expected VST3 bundle is missing: $bundle"
printf '\nVST3 build complete: %s\n' "$bundle"
printf 'Factory assets: %s\n' "$repo_dir/assets/installer/Surge Synth Team/OB-Xf"
printf 'See README.md for manual plugin and factory asset installation.\n'
