#!/usr/bin/env python3
"""Dumps all project source code into a single text file,
excluding packages / dependencies / build artifacts."""

import os
from pathlib import Path

PROJECT = Path(__file__).resolve().parent
OUTPUT = PROJECT / "code_dump.txt"

EXCLUDE_DIRS = {
    ".git",
    ".godot",
    "addons",
    "__pycache__",
    "venv",
    "env",
    ".venv",
    "node_modules",
    "export",
    "android",
    "ios",
    "web",
    "assets",
}

EXCLUDE_EXTENSIONS = {
    ".import",
    ".uid",
    ".cache",
    ".bin",
}

ALWAYS_INCLUDE_EXTENSIONS = {
    ".gd",
    ".tscn",
    ".tres",
    ".cfg",
    ".json",
    ".yml",
    ".yaml",
    ".md",
    ".txt",
    ".svg",
    ".py",
    ".gitignore",
    ".gdlintrc",
}


def should_skip(path: Path) -> bool:
    parts = path.relative_to(PROJECT).parts
    if any(p in EXCLUDE_DIRS for p in parts):
        return True
    if path.suffix in EXCLUDE_EXTENSIONS:
        return True
    if path.name == "project.godot":
        return False
    return False


def collect_files() -> list[Path]:
    files: list[Path] = []
    for root, dirs, names in os.walk(PROJECT):
        root_p = Path(root)
        rel = root_p.relative_to(PROJECT)
        if any(p in EXCLUDE_DIRS for p in rel.parts):
            continue
        for name in names:
            fp = root_p / name
            if should_skip(fp):
                continue
            ext = fp.suffix
            if ext in ALWAYS_INCLUDE_EXTENSIONS or ext == "":
                # Check if it's a text-like file
                pass
            else:
                continue
            files.append(fp)
    files.sort(key=lambda p: p.relative_to(PROJECT))
    return files


def main():
    files = collect_files()

    with open(OUTPUT, "w", encoding="utf-8") as out:
        out.write("=" * 72 + "\n")
        out.write("SCRABBLE PROJECT — FULL CODE DUMP\n")
        out.write(f"Generated from: {PROJECT}\n")
        out.write("=" * 72 + "\n\n")

        for fp in files:
            rel = fp.relative_to(PROJECT)
            try:
                content = fp.read_text(encoding="utf-8")
            except Exception as e:
                content = f"[ERROR reading file: {e}]\n"

            out.write("-" * 72 + "\n")
            out.write(f"FILE: {rel}\n")
            out.write(f"PATH: {fp}\n")
            out.write("-" * 72 + "\n")
            out.write(content)
            if not content.endswith("\n"):
                out.write("\n")
            out.write("\n")

    print(f"Done — wrote {len(files)} files to {OUTPUT}")


if __name__ == "__main__":
    main()
