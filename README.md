# Bucky Builder

[![Build](https://github.com/ardanlabs/bucky-builder/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/ardanlabs/bucky-builder/actions/workflows/build.yml)

## Prebuilt whisper.cpp binaries for Linux, macOS, and Windows

This repo builds binary versions of `whisper.cpp` shared libraries for
every platform [bucky](https://github.com/ardanlabs/bucky) supports, so
`bucky install` has a single source of truth and a single release cadence.
That includes accelerated Linux configurations upstream does not ship
(CUDA / Vulkan) and the macOS / Windows variants we want pinned to the
same tag.

New releases are automatically built for the latest release version of
`whisper.cpp`. The latest release is checked twice daily.

Used by [bucky](https://github.com/ardanlabs/bucky)'s `bucky install`
command. bucky lets you write Go applications that directly integrate the
latest `whisper.cpp` libraries.

Mirrors the role [hybridgroup/llama-cpp-builder](https://github.com/hybridgroup/llama-cpp-builder)
plays for [yzma](https://github.com/hybridgroup/yzma).

## CUDA

Currently supported CUDA build configurations:

| CPU arch | OS           | CUDA   | Nvidia Compute arch |
| -------- | ------------ | ------ | ------------------- |
| amd64    | Ubuntu 24.04 | 12.9.1 | 86, 89              |
| arm64    | Ubuntu 22.04 | 12.9.1 | 87                  |
| x64      | Windows      | 12.4   | 86, 89              |

Compute architectures `86` and `89` are those used by consumer video cards
(RTX 3090 / 4090).

Compute architecture `87` is used by Jetson Orin and Jetson AGX.

## Vulkan

Currently supported Vulkan build configurations:

| CPU arch | OS           | Vulkan SDK                  |
| -------- | ------------ | --------------------------- |
| amd64    | Ubuntu 24.04 | latest LunarG noble package |
| arm64    | Ubuntu 22.04 | 1.4.335.0                   |

The arm64 prebuilt Vulkan SDK comes from
<https://github.com/jakoch/vulkan-sdk-arm>.

## CPU

Currently supported CPU build configurations:

| CPU arch | OS           | Notes                                       |
| -------- | ------------ | ------------------------------------------- |
| amd64    | Ubuntu 24.04 | `GGML_CPU_ALL_VARIANTS=ON` runtime dispatch |
| arm64    | Ubuntu 22.04 |                                             |
| x64      | Windows      | `GGML_CPU_ALL_VARIANTS=ON` runtime dispatch |

## macOS

Currently supported macOS build configurations:

| CPU arch         | OS              | Notes                                     |
| ---------------- | --------------- | ----------------------------------------- |
| arm64 + x86_64   | macOS 13.3+     | Universal xcframework; Metal + CoreML     |

Built on `macos-latest` by running upstream's `build-xcframework.sh` and
then repackaging with only the macOS slice via `xcodebuild
-create-xcframework`, so the artifact is small even though the build is
the canonical upstream one.

## Artifacts

For each whisper.cpp release tag (e.g. `v1.8.4`), this repo publishes:

| Filename                                              |
| ----------------------------------------------------- |
| `whisper-vX.Y.Z-bin-ubuntu-cpu-x64.tar.gz`            |
| `whisper-vX.Y.Z-bin-ubuntu-cpu-arm64.tar.gz`          |
| `whisper-vX.Y.Z-bin-ubuntu-cuda-x64.tar.gz`           |
| `whisper-vX.Y.Z-bin-ubuntu-cuda-arm64.tar.gz`         |
| `whisper-vX.Y.Z-bin-ubuntu-vulkan-x64.tar.gz`         |
| `whisper-vX.Y.Z-bin-ubuntu-vulkan-arm64.tar.gz`       |
| `whisper-vX.Y.Z-bin-darwin-metal-universal.zip`       |
| `whisper-vX.Y.Z-bin-windows-cpu-x64.zip`              |
| `whisper-vX.Y.Z-bin-windows-cuda-x64.zip`             |

All tarballs unpack to `whisper-vX.Y.Z/` containing `libwhisper.so`,
`libggml.so`, `libggml-base.so`, `libggml-cpu.so`, the per-microarch CPU
variants from `GGML_CPU_ALL_VARIANTS=ON` (`libggml-cpu-x64.so`,
`libggml-cpu-haswell.so`, `libggml-cpu-skylakex.so`, `libggml-cpu-zen4.so`,
…), and (where applicable) `libggml-cuda.so` / `libggml-vulkan.so`. The
backend MODULEs are installed alongside the core libs via
`-DCMAKE_INSTALL_BINDIR=lib` so the dlopen-based registry
(`ggml_backend_load_all_from_path`) finds them on a single path. RPATH is
`$ORIGIN`, so the libraries are self-contained regardless of where bucky
drops them.

## Integrity manifests

The Build workflow automatically creates an integrity manifest after it builds
all supported platform bundles. Developers do not need to calculate or add
digests manually for new releases.

Each release publishes these files:

| Filename                    | Contents                                                       |
| --------------------------- | -------------------------------------------------------------- |
| `digests/vX.Y.Z.json`       | SHA-256 values for every archive and its installed files/links |
| `digests/vX.Y.Z.json.sha256` | SHA-256 of the exact manifest bytes                            |

The SHA-256 of the manifest is the version-level digest used in a Bucky pin:

```text
vX.Y.Z@sha256:<manifest-digest>
```

That single pin works for every supported platform. Bucky authenticates the
manifest with the supplied digest, selects the appropriate CPU, CUDA, Vulkan,
Metal, or Windows bundle, and verifies that archive against its entry in the
authenticated manifest before extraction.

For every new whisper.cpp release, the workflow:

1. Builds all supported bundles.
2. Generates the manifest and its checksum.
3. Uploads both files as GitHub release assets.
4. Commits both files under `digests/` on `main`.
5. Publishes the `digests/` directory through GitHub Pages.
6. Prints the complete Bucky pin in the release notes and workflow summary.

## How to check the latest version

```
VERSION=$(curl -s https://ardanlabs.github.io/bucky-builder/version.json | jq -r '.tag_name')
```

bucky reads this instead of the GitHub releases API to avoid the
unauthenticated rate limit.

Integrity manifests are available as release assets and at the GitHub Pages
URLs `https://ardanlabs.github.io/bucky-builder/digests/<tag>.json` and
`https://ardanlabs.github.io/bucky-builder/digests/<tag>.json.sha256`. To fetch
and verify the exact manifest bytes:

```sh
curl -fLO "https://ardanlabs.github.io/bucky-builder/digests/${VERSION}.json"
curl -fLO "https://ardanlabs.github.io/bucky-builder/digests/${VERSION}.json.sha256"
if command -v sha256sum >/dev/null; then
    sha256sum -c "${VERSION}.json.sha256"
else
    shasum -a 256 -c "${VERSION}.json.sha256"
fi
DIGEST=$(awk '{print $1}' "${VERSION}.json.sha256")
printf '%s@sha256:%s\n' "$VERSION" "$DIGEST"
```

The resulting `<tag>@sha256:<digest>` pin is also printed in the release job
summary and release notes.

## Rebuilding the latest tag

The Build workflow always selects the latest upstream whisper.cpp tag. Use the
`force` input to rebuild it when bucky-builder already has a release with that
tag:

```
gh workflow run Build --repo ardanlabs/bucky-builder -f force=true
```

Or via the Actions tab → Build → Run workflow.

The checked-in `v1.9.3` manifest is a one-time backfill for bundles that were
published before manifest generation was added. After these changes reach
`main`, run the forced build once to attach the manifest files to the existing
release, update its release notes, and publish the files through GitHub Pages.

## Adding a new build target

Add a new job to [`.github/workflows/build.yml`](./.github/workflows/build.yml)
that copies one of the existing CUDA / Vulkan / CPU jobs as a starting
point, then add it to the `release` job's `needs:` list. Keep the artifact
filename pattern `whisper-${TAG}-bin-ubuntu-${backend}-${arch}.tar.gz` so
bucky's resolver in [`pkg/download/download.go`](https://github.com/ardanlabs/bucky/blob/main/pkg/download/download.go)
can find it.

## License

Apache-2.0 — see [LICENSE](./LICENSE). The whisper.cpp binaries inside each
tarball are MIT-licensed by their upstream authors; this repo only packages
them.
