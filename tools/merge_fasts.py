"""Merge another app's TSV history into a Tavryn import JSON."""

from __future__ import annotations

import json
from datetime import datetime, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parent
BACKUP = ROOT / "tavryn_backup.json"
TSV = ROOT / "other_app_fasts.tsv"
OUT = ROOT / "tavryn_import.json"

PROTOCOLS = {
    "14:10": ("14-10", "14h/10h", 14 * 60),
    "16:8": ("16-8", "16h/8h", 16 * 60),
    "18:6": ("18-6", "18h/6h", 18 * 60),
    "20:4": ("20-4", "20h/4h", 20 * 60),
    "12:12": ("12-12", "12h/12h", 12 * 60),
}


def parse_dt(raw: str) -> datetime:
    text = raw.strip()
    if text.endswith("Z"):
        text = text[:-1]
    return datetime.fromisoformat(text)


def load_backup_fasts(data: dict) -> list[dict]:
    raw = data["fasts"]
    if isinstance(raw, str):
        return json.loads(raw)
    return list(raw)


def near(a: datetime, b: datetime, seconds: int = 180) -> bool:
    return abs((a - b).total_seconds()) <= seconds


def convert_row(fast: str, start_raw: str, end_raw: str, index: int) -> dict | None:
    proto = PROTOCOLS.get(fast.strip())
    if proto is None:
        raise SystemExit(f"Unknown protocol {fast!r}")
    start = parse_dt(start_raw)
    end = parse_dt(end_raw)
    if end < start:
        return None
    if (end - start) < timedelta(minutes=1):
        return None
    schedule_id, schedule_name, goal = proto
    return {
        "id": f"import-{index}-{int(start.timestamp())}",
        "startAt": start.isoformat(),
        "endAt": end.isoformat(),
        "scheduleId": schedule_id,
        "scheduleName": schedule_name,
        "goalMinutes": goal,
        "note": None,
        "feeling": None,
    }


def main() -> None:
    backup = json.loads(BACKUP.read_text(encoding="utf-8"))
    existing = load_backup_fasts(backup)
    existing_starts = [parse_dt(row["startAt"]) for row in existing]

    skipped_short = 0
    skipped_dup = 0
    imported: list[dict] = []

    for index, line in enumerate(TSV.read_text(encoding="utf-8").splitlines()):
        if not line.strip() or line.startswith("Fast"):
            continue
        parts = line.split("\t")
        if len(parts) < 3:
            raise SystemExit(f"Expected tab-separated row, got: {line!r}")
        row = convert_row(parts[0], parts[1], parts[2], index)
        if row is None:
            skipped_short += 1
            continue
        start = parse_dt(row["startAt"])
        if any(near(start, other) for other in existing_starts):
            skipped_dup += 1
            continue
        imported.append(row)
        existing_starts.append(start)

    merged = existing + imported
    merged.sort(key=lambda row: row["startAt"], reverse=True)

    actives = [row for row in merged if row.get("endAt") in (None, "")]
    if len(actives) > 1:
        raise SystemExit(f"More than one active fast after merge: {len(actives)}")

    out = dict(backup)
    out["exported_at"] = datetime.now().isoformat()
    out["export_note"] = (
        "Merged Tavryn backup with one-time import from another fasting app."
    )
    out["fasts"] = json.dumps(merged, separators=(",", ":"))
    OUT.write_text(json.dumps(out, indent=2), encoding="utf-8")
    print(f"Kept from Tavryn: {len(existing)}")
    print(f"Imported: {len(imported)}")
    print(f"Skipped duplicates: {skipped_dup}")
    print(f"Skipped under 1 minute: {skipped_short}")
    print(f"Total in file: {len(merged)}")
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    main()
