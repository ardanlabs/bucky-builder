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

| CPU arch | OS           | CUDA   | Nvidia Compute arch     |
| -------- | ------------ | ------ | ----------------------- |
| amd64    | Ubuntu 24.04 | 12.9.1 | 75 PTX, 80 PTX, 86, 89 |
| arm64    | Ubuntu 22.04 | 12.9.1 | 87, 121                 |
| amd64    | Ubuntu 24.04 | 13.0.2 | 75 PTX, 80 PTX, 86, 89 |
| arm64    | Ubuntu 22.04 | 13.0.2 | 87, 121                 |
| x64      | Windows      | 12.4   | 75 PTX, 80 PTX, 86, 89 |

Compute architectures `75` and `80` cover Turing and first-generation Ampere
GPUs (including RTX 20-series, GTX 16-series, T4, A100, and A30) via
driver-compiled PTX. Compute architectures `86` and `89` are built natively
for consumer video cards (RTX 3090 / 4090).

Compute architecture `87` is used by Jetson Orin and Jetson AGX. Compute
architecture `121` is built natively for DGX Spark.

Linux supports both CUDA 12 and CUDA 13. The unnumbered `cuda` bundles use
CUDA 12.9.1, while
`cuda-13` bundles use CUDA 13.0.2, matching llama-cpp-builder's CUDA 13 toolkit.
Both CUDA majors build on pull requests; the CUDA 13 jobs also check that
`libggml-cuda.so` links `libcudart.so.13` and `libcublas.so.13` before packaging.

Linux bundles do not include NVIDIA's CUDA runtime or cuBLAS libraries. The
host or container must supply the matching major version: `.so.12` for CUDA
12 bundles, `.so.13` for CUDA 13 bundles, plus a compatible NVIDIA driver.
A driver's reported CUDA version is a compatibility capability, not evidence
that the corresponding user-space libraries are installed. CUDA 12 and 13
runtime libraries can coexist in the same image. Keep Jetson Orin deployments
on CUDA 12 unless their installed JetPack/runtime supports CUDA 13.

Windows remains on CUDA 12.4. Its CUDA bundle includes NVIDIA runtime DLLs,
so a compatible NVIDIA driver is required, but a separate CUDA toolkit
installation is not.

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
| arm64    | Ubuntu 22.04 | `GGML_CPU_ALL_VARIANTS=ON`; GCC 14          |
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

The build workflow publishes these eleven bundles for new whisper.cpp
release tags. Older releases may contain fewer bundles, including releases
from before CUDA 13 support was added.

| Filename                                              |
| ----------------------------------------------------- |
| `whisper-vX.Y.Z-bin-ubuntu-cpu-x64.tar.gz`            |
| `whisper-vX.Y.Z-bin-ubuntu-cpu-arm64.tar.gz`          |
| `whisper-vX.Y.Z-bin-ubuntu-cuda-x64.tar.gz`           |
| `whisper-vX.Y.Z-bin-ubuntu-cuda-arm64.tar.gz`         |
| `whisper-vX.Y.Z-bin-ubuntu-cuda-13-x64.tar.gz`        |
| `whisper-vX.Y.Z-bin-ubuntu-cuda-13-arm64.tar.gz`      |
| `whisper-vX.Y.Z-bin-ubuntu-vulkan-x64.tar.gz`         |
| `whisper-vX.Y.Z-bin-ubuntu-vulkan-arm64.tar.gz`       |
| `whisper-vX.Y.Z-bin-darwin-metal-universal.zip`       |
| `whisper-vX.Y.Z-bin-windows-cpu-x64.zip`              |
| `whisper-vX.Y.Z-bin-windows-cuda-x64.zip`             |

All tarballs unpack to `whisper-vX.Y.Z/` containing `libwhisper.so`,
`libggml.so`, `libggml-base.so`, `libggml-cpu.so`, the per-microarch CPU
variants from `GGML_CPU_ALL_VARIANTS=ON` (on x64: `libggml-cpu-x64.so`,
`libggml-cpu-haswell.so`, `libggml-cpu-skylakex.so`, `libggml-cpu-zen4.so`,
…), and (where applicable) `libggml-cuda.so` / `libggml-vulkan.so`. The
backend MODULEs are installed alongside the core libs via
`-DCMAKE_INSTALL_BINDIR=lib` so the dlopen-based registry
(`ggml_backend_load_all_from_path`) finds them on a single path. RPATH is
`$ORIGIN`, so the bundled libraries can find each other regardless of where
bucky drops them. System dependencies, including the matching CUDA runtime
libraries for CUDA bundles, must still be provided by the host or container.

## Integrity manifests

The Build workflow automatically creates an integrity manifest after it builds
all supported platform bundles. Developers do not need to calculate or add
digests manually for new releases.

Each release with manifest generation publishes these GitHub release assets:

| Filename                    | Contents                                                       |
| --------------------------- | -------------------------------------------------------------- |
| `vX.Y.Z.json`              | SHA-256 values for every archive and its installed files/links |
| `vX.Y.Z.json.sha256`        | SHA-256 of the exact manifest bytes                            |

In the repository and on GitHub Pages, these files live under `digests/`.

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

**Pinned-manifest warning:** a forced rebuild replaces release archives and
regenerates the manifest. Adding CUDA 13 entries also changes its SHA-256, so
an existing Bucky release's manifest pin will reject the replacement. Prefer
publishing the new build matrix with the next upstream tag. Backfilling an
existing tag requires coordinating new consumer pins and the effect on older
Bucky releases; do not treat it as a transparent update.

## Adding a new build target

Add a new job to [`.github/workflows/build.yml`](./.github/workflows/build.yml)
that copies one of the existing CUDA / Vulkan / CPU jobs as a starting
point, then add it to the `release` job's `needs:` list and artifact-download
steps. The digest generator discovers every downloaded archive, including
both CUDA majors. Keep the artifact
filename pattern `whisper-${TAG}-bin-ubuntu-${backend}-${arch}.tar.gz` so
bucky's resolver in [`pkg/download/download.go`](https://github.com/ardanlabs/bucky/blob/main/pkg/download/download.go)
can find it. Versioned backends such as `cuda-13` also require corresponding
resolver support in Bucky.

## License

Apache-2.0 — see [LICENSE](./LICENSE). The whisper.cpp binaries inside each
tarball are MIT-licensed by their upstream authors; this repo only packages
them.
