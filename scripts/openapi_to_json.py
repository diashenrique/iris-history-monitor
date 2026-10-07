#!/usr/bin/env python3
"""Writes specs/<feature>/contracts/openapi.json from openapi.yaml.

ObjectScript has no YAML parser, so the contract tests read this JSON copy. The YAML stays the
source of truth; CI regenerates the JSON and fails when the committed copy differs.

Usage: python3 scripts/openapi_to_json.py [path/to/openapi.yaml]
"""
import json
import pathlib
import sys

import yaml

DEFAULT = "specs/001-api-v1/contracts/openapi.yaml"


def main(argv):
    src = pathlib.Path(argv[1] if len(argv) > 1 else DEFAULT)
    with src.open(encoding="utf-8") as fh:
        doc = yaml.safe_load(fh)
    out = src.with_suffix(".json")
    out.write_text(json.dumps(doc, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"wrote {out}")


if __name__ == "__main__":
    main(sys.argv)
