#!/usr/bin/env python3
"""Convert legacy Android Wrait entries CSV to the Flutter import format."""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path


SOURCE_FIELDS = {
    "rawTranscript",
    "cleanedText",
    "isDraft",
    "language",
    "createdAt",
    "wordCount",
}

TARGET_FIELDS = [
    "type",
    "created_at",
    "language",
    "word_count",
    "raw_transcript",
    "cleaned_text",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Convert entries/wrait-android.csv to entries/wrait-flutter.csv."
    )
    parser.add_argument(
        "source",
        nargs="?",
        default="entries/wrait-android.csv",
        help="Android CSV input path.",
    )
    parser.add_argument(
        "target",
        nargs="?",
        default="entries/wrait-flutter.csv",
        help="Flutter CSV output path.",
    )
    return parser.parse_args()


def require_source_fields(fieldnames: list[str] | None) -> None:
    missing = SOURCE_FIELDS.difference(fieldnames or [])
    if missing:
        raise ValueError(f"missing required source column(s): {', '.join(sorted(missing))}")


def converted_rows(reader: csv.DictReader) -> tuple[int, list[dict[str, str]]]:
    require_source_fields(reader.fieldnames)

    rows = []
    for row_number, row in enumerate(reader, start=2):
        is_draft = row["isDraft"].strip().lower()
        if is_draft not in {"true", "false"}:
            raise ValueError(f"invalid isDraft value on row {row_number}: {row['isDraft']!r}")

        rows.append(
            {
                "type": "draft" if is_draft == "true" else "saved",
                "created_at": row["createdAt"],
                "language": row["language"],
                "word_count": row["wordCount"],
                "raw_transcript": row["rawTranscript"],
                "cleaned_text": row["cleanedText"],
            }
        )

    return len(rows), rows


def main() -> int:
    args = parse_args()
    source = Path(args.source)
    target = Path(args.target)

    try:
        with source.open("r", encoding="utf-8-sig", newline="") as source_file:
            reader = csv.DictReader(source_file)
            count, rows = converted_rows(reader)

        target.parent.mkdir(parents=True, exist_ok=True)
        with target.open("w", encoding="utf-8", newline="") as target_file:
            writer = csv.DictWriter(target_file, fieldnames=TARGET_FIELDS)
            writer.writeheader()
            writer.writerows(rows)
    except (OSError, csv.Error, ValueError) as error:
        print(f"conversion failed: {error}", file=sys.stderr)
        return 1

    print(f"converted {count} row(s): {source} -> {target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
