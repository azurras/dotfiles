#!/usr/bin/env python3

from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple


LINE_RE = re.compile(r'^(tap|brew|cask|mas)\s+"([^"]+)"')


@dataclass(frozen=True)
class Item:
    kind: str
    name: str
    lineno: int
    raw: str


def parse_brewfile(path: Path) -> List[Item]:
    items: List[Item] = []
    for i, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        s = raw.strip()
        if not s or s.startswith("#"):
            continue
        m = LINE_RE.match(s)
        if not m:
            # Allow arbitrary ruby in Brewfile, but warn.
            items.append(Item("unknown", s, i, raw))
            continue
        items.append(Item(m.group(1), m.group(2), i, raw))
    return items


def find_duplicates(items: List[Item]) -> List[str]:
    seen: Dict[Tuple[str, str], Item] = {}
    errs: List[str] = []
    for it in items:
        if it.kind == "unknown":
            continue
        key = (it.kind, it.name)
        if key in seen:
            prev = seen[key]
            errs.append(
                f"duplicate: {it.kind} \"{it.name}\" (lines {prev.lineno} and {it.lineno})"
            )
        else:
            seen[key] = it
    return errs


def find_conflicts(items: List[Item]) -> List[str]:
    # Groups where only one should be present. This is intentionally small and
    # repo-opinionated; add more as needed.
    groups = [
        ("cask", {"handbrake", "handbrake-app"}),
    ]

    present: Dict[str, Set[str]] = {"tap": set(), "brew": set(), "cask": set(), "mas": set()}
    by_kind_name: Dict[Tuple[str, str], List[Item]] = {}
    for it in items:
        if it.kind in present:
            present[it.kind].add(it.name)
            by_kind_name.setdefault((it.kind, it.name), []).append(it)

    errs: List[str] = []
    for kind, names in groups:
        hit = sorted(n for n in names if n in present.get(kind, set()))
        if len(hit) > 1:
            locs: List[str] = []
            for name in hit:
                for it in by_kind_name.get((kind, name), []):
                    locs.append(f"{name}@{it.lineno}")
            errs.append(f"conflict: {kind} entries are mutually exclusive: {', '.join(locs)}")
    return errs


def find_warnings(items: List[Item]) -> List[str]:
    warns: List[str] = []
    for it in items:
        if it.kind == "unknown":
            warns.append(f"warning: unparsed Brewfile line {it.lineno}: {it.raw.strip()}")

    # "Known-problem" packages we prefer to flag without failing CI.
    deprecated_casks = set()
    deprecated_brews = {"youtube-dl"}
    for it in items:
        if it.kind == "brew" and it.name in deprecated_brews:
            warns.append(
                f'warning: brew "{it.name}" at line {it.lineno} is often replaced by "yt-dlp"'
            )
        if it.kind == "cask" and it.name in deprecated_casks:
            warns.append(f'warning: cask "{it.name}" at line {it.lineno} looks deprecated')
    return warns


def main(argv: List[str]) -> int:
    path = Path(argv[1]) if len(argv) > 1 else Path("Brewfile")
    if not path.exists():
        print(f"error: Brewfile not found at {path}", file=sys.stderr)
        return 2

    items = parse_brewfile(path)
    errors: List[str] = []
    errors.extend(find_duplicates(items))
    errors.extend(find_conflicts(items))
    warnings = find_warnings(items)

    if warnings:
        for w in warnings:
            print(w, file=sys.stderr)

    if errors:
        for e in errors:
            print(f"error: {e}", file=sys.stderr)
        return 1

    print(f"ok: {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

