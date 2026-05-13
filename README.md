# Bucky Builder

## Prebuilt binaries for CPU, CUDA, and Vulkan on Linux

This repo builds binary versions of `whisper.cpp` shared libraries for
architectures that are not already part of the normal upstream builds, such
as Linux with CUDA or Vulkan support, and Linux arm64 CPU.

New releases are automatically built for the latest release version of
`whisper.cpp`. The latest release is checked once per hour.

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

## Artifacts

For each whisper.cpp release tag (e.g. `v1.8.4`), this repo publishes:

| Filename                                        |
| ----------------------------------------------- |
| `whisper-vX.Y.Z-bin-ubuntu-cpu-x64.tar.gz`      |
| `whisper-vX.Y.Z-bin-ubuntu-cpu-arm64.tar.gz`    |
| `whisper-vX.Y.Z-bin-ubuntu-cuda-x64.tar.gz`     |
| `whisper-vX.Y.Z-bin-ubuntu-cuda-arm64.tar.gz`   |
| `whisper-vX.Y.Z-bin-ubuntu-vulkan-x64.tar.gz`   |
| `whisper-vX.Y.Z-bin-ubuntu-vulkan-arm64.tar.gz` |

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

## How to check the latest version

```
VERSION=$(curl -s https://ardanlabs.github.io/bucky-builder/version.json | jq -r '.tag_name')
```

bucky reads this instead of the GitHub releases API to avoid the
unauthenticated rate limit.

## Manually rebuilding a single tag

```
gh workflow run Build --repo ardanlabs/bucky-builder
```

Or via the Actions tab → Build → Run workflow.

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
