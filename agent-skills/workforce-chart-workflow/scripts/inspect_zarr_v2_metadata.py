#!/usr/bin/env python3
"""Print dimensions and coordinate values from a consolidated Zarr v2 store."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numcodecs
import numpy as np


def _coordinate_values(store: Path, metadata: dict[str, object], name: str) -> list[object]:
    array = metadata[f"{name}/.zarray"]
    assert isinstance(array, dict)
    shape = array["shape"]
    chunks = array["chunks"]
    assert isinstance(shape, list) and isinstance(chunks, list)
    if len(shape) != 1 or len(chunks) != 1:
        raise ValueError(f"{name!r} is not a one-dimensional coordinate")
    codec = numcodecs.get_codec(array["compressor"])
    dtype = np.dtype(array["dtype"])
    values: list[object] = []
    for index, start in enumerate(range(0, shape[0], chunks[0])):
        decoded = codec.decode((store / name / str(index)).read_bytes())
        chunk = np.frombuffer(decoded, dtype=dtype)
        values.extend(chunk[: min(chunks[0], shape[0] - start)].tolist())
    return values


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("store", type=Path, help="Path to a consolidated Zarr v2 store")
    parser.add_argument(
        "--coordinate",
        action="append",
        default=[],
        help="One-dimensional coordinate to print; may be supplied more than once",
    )
    args = parser.parse_args()
    metadata_path = args.store / ".zmetadata"
    metadata = json.loads(metadata_path.read_text())["metadata"]
    if not isinstance(metadata, dict):
        raise ValueError(f"Invalid consolidated metadata in {metadata_path}")

    for key in sorted(metadata):
        if not key.endswith("/.zarray"):
            continue
        array = metadata[key]
        if not isinstance(array, dict):
            continue
        name = key.removesuffix("/.zarray")
        attrs = metadata.get(f"{name}/.zattrs", {})
        dimensions = attrs.get("_ARRAY_DIMENSIONS") if isinstance(attrs, dict) else None
        print(f"{name}: dims={dimensions} shape={array['shape']} chunks={array['chunks']}")

    for name in args.coordinate:
        print(f"{name}: {_coordinate_values(args.store, metadata, name)}")


if __name__ == "__main__":
    main()
