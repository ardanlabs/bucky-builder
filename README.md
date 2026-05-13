# bucky-builder

Prebuilt [whisper.cpp](https://github.com/ggml-org/whisper.cpp) shared
libraries for Linux, used by [bucky](https://github.com/ardanlabs/bucky)'s
`bucky install` command.

Mirrors the role [hybridgroup/llama-cpp-builder](https://github.com/hybridgroup/llama-cpp-builder)
plays for [yzma](https://github.com/hybridgroup/yzma): whisper.cpp upstream
publishes no Linux release artifact, so this repo builds them on a cron and
republishes them as GitHub Releases tagged with the matching whisper.cpp
version.

## Artifacts

For each whisper.cpp release tag (e.g. `v1.8.4`), this repo publishes:

| Filename | Arch | Backend | Notes |
|---|---|---|---|
| `whisper-vX.Y.Z-bin-ubuntu-cpu-x64.tar.gz` | amd64 | CPU | `GGML_CPU_ALL_VARIANTS=ON` runtime dispatch |
| `whisper-vX.Y.Z-bin-ubuntu-cpu-arm64.tar.gz` | arm64 | CPU | |
| `whisper-vX.Y.Z-bin-ubuntu-cuda-x64.tar.gz` | amd64 | CUDA 12.9 | sm_86;sm_89 (RTX 3090/4090) |
| `whisper-vX.Y.Z-bin-ubuntu-cuda-arm64.tar.gz` | arm64 | CUDA 12.9 | sm_87 (Jetson Orin) |
| `whisper-vX.Y.Z-bin-ubuntu-vulkan-x64.tar.gz` | amd64 | Vulkan 1.4.335 | |
| `whisper-vX.Y.Z-bin-ubuntu-vulkan-arm64.tar.gz` | arm64 | Vulkan 1.4.335 | |

All tarballs unpack to `whisper-vX.Y.Z/` containing `libwhisper.so`,
`libggml.so`, `libggml-base.so`, `libggml-cpu.so`, and (where applicable)
`libggml-cuda.so` / `libggml-vulkan.so`. RPATH is `$ORIGIN`, so the libraries
are self-contained regardless of where bucky drops them.

## Discovery endpoint

The latest version is published as JSON to GitHub Pages at:

```
https://ardanlabs.github.io/bucky-builder/version.json
```

Schema:

```json
{"tag_name": "v1.8.4"}
```

bucky reads this instead of the GitHub releases API to avoid the
unauthenticated rate limit.

## How a release happens

```
hourly cron (15 * * * *)
       │
       ▼
╭──────────────────────────╮
│ check-version            │  diff upstream whisper.cpp tag vs own latest tag
│ (skip if equal)          │  → all build jobs gated on tag mismatch
╰──────────────┬───────────╯
               │
   ┌───────────┼───────────┬──────────────┬──────────────┬──────────────┐
   ▼           ▼           ▼              ▼              ▼              ▼
 cpu-amd64  cpu-arm64  cuda-amd64    cuda-arm64    vulkan-amd64   vulkan-arm64
   │           │           │              │              │              │
   └───────────┴───────────┴──────┬───────┴──────────────┴──────────────┘
                                  ▼
                         ╭─────────────────╮
                         │ release         │  ncipollo/release-action
                         │ tag = vX.Y.Z    │
                         ╰────────┬────────╯
                                  │
                         ╭────────▼─────────╮
                         │ publish-version  │  → version.json on GitHub Pages
                         ╰────────┬─────────╯
                                  │
                         ╭────────▼──────────────╮
                         │ trigger-bucky-tests   │  workflow_dispatch on
                         │ (needs PAT secret)    │  ardanlabs/bucky CI
                         ╰───────────────────────╯
```

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
