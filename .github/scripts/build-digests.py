#!/usr/bin/env python3
"""Build Bucky's release archive and installed-file digest manifest."""

import argparse
import hashlib
import json
import os
import pathlib
import tarfile
import zipfile
from datetime import datetime, timezone


def stream_digest(stream):
    value = hashlib.sha256()
    for block in iter(lambda: stream.read(1024 * 1024), b""):
        value.update(block)
    return value.hexdigest()


def file_digest(path):
    with path.open("rb") as stream:
        return stream_digest(stream)


def linux_contents(archive):
    files, links = {}, {}
    with tarfile.open(archive, "r:gz") as source:
        for member in source.getmembers():
            parts = pathlib.PurePosixPath(member.name).parts
            if len(parts) < 2 or parts[0] in ("", ".", ".."):
                continue
            name = pathlib.PurePosixPath(*parts[1:]).as_posix()
            if ".." in pathlib.PurePosixPath(name).parts:
                raise ValueError(f"unsafe archive path: {member.name}")
            if member.isfile():
                stream = source.extractfile(member)
                if stream is None:
                    raise ValueError(f"could not read {member.name}")
                files[name] = stream_digest(stream)
            elif member.issym():
                links[name] = member.linkname
    return files, links


def windows_contents(archive):
    files = {}
    with zipfile.ZipFile(archive) as source:
        for info in source.infolist():
            if info.is_dir() or not info.filename.lower().endswith(".dll"):
                continue
            name = pathlib.PurePosixPath(info.filename).name
            if name in files:
                raise ValueError(f"duplicate flattened DLL: {name}")
            with source.open(info) as stream:
                files[name] = stream_digest(stream)
    return files, {}


def darwin_contents(archive):
    suffix = "/whisper.framework/Versions/A/whisper"
    with zipfile.ZipFile(archive) as source:
        matches = [item for item in source.infolist() if item.filename.endswith(suffix)]
        if len(matches) != 1:
            raise ValueError(f"expected one macOS framework binary, found {len(matches)}")
        with source.open(matches[0]) as stream:
            return {"libwhisper.dylib": stream_digest(stream)}, {}


def generated_time(value):
    if value:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    elif os.environ.get("SOURCE_DATE_EPOCH"):
        parsed = datetime.fromtimestamp(int(os.environ["SOURCE_DATE_EPOCH"]), timezone.utc)
    else:
        parsed = datetime.now(timezone.utc)
    return parsed.astimezone(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("tag")
    parser.add_argument("archives", type=pathlib.Path)
    parser.add_argument("output", type=pathlib.Path)
    parser.add_argument("--generated", help="ISO-8601 generation time (or use SOURCE_DATE_EPOCH)")
    args = parser.parse_args()

    archives = sorted(
        path for path in args.archives.iterdir()
        if path.is_file() and (path.name.endswith(".tar.gz") or path.name.endswith(".zip"))
    )
    if not archives:
        parser.error("no release archives found")

    assets = {}
    for archive in archives:
        archive_sha256 = file_digest(archive)
        if "-ubuntu-" in archive.name:
            files, links = linux_contents(archive)
        elif "-windows-" in archive.name:
            files, links = windows_contents(archive)
        elif "-darwin-" in archive.name:
            files, links = darwin_contents(archive)
        else:
            raise ValueError(f"unrecognized release archive: {archive.name}")
        if not files:
            raise ValueError(f"no installed files found in {archive.name}")
        assets[archive.name] = {"sha256": archive_sha256, "files": files, "links": links}

    manifest = {
        "version": 1,
        "tag": args.tag,
        "generated": generated_time(args.generated),
        "sources": {"ardanlabs/bucky-builder": {"tag": args.tag, "assets": assets}},
    }
    args.output.mkdir(parents=True, exist_ok=True)
    output = args.output / f"{args.tag}.json"
    output.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    checksum = file_digest(output)
    checksum_file = args.output / f"{args.tag}.json.sha256"
    checksum_file.write_text(f"{checksum}  {output.name}\n", encoding="ascii")
    print(f"{args.tag}@sha256:{checksum}")


if __name__ == "__main__":
    main()
