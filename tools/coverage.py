#!/usr/bin/env python3
"""
Line coverage for GDScript, measured by source instrumentation.

There is no working line-coverage tool for GUT on Godot 4 (nano-coverage is an
alpha GDExtension whose only framework integration is gdUnit4), so this does the
job directly:

  1. Copy the project into .coverage/build/.
  2. Rewrite every file under scripts/ so each executable statement is preceded
     by a `CovTracker.hit(file_id, line)` call. Line numbers recorded are the
     ORIGINAL ones, so reports point at the real source.
  3. Run the GUT suite against the copy. An autoload flushes the hit counts.
  4. Emit lcov.info plus a per-file summary.

What is measured: executable statements inside function bodies. Class-level
declarations (`var x := ...`, `const`, `signal`) are not instrumentable -- a
statement cannot be inserted between them -- so they are excluded from both the
numerator and the denominator, and counted separately in the report.

Usage:
    python3 tools/coverage.py [--godot PATH] [--fail-under 95]
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD = os.path.join(PROJECT, ".coverage", "build")
SOURCE_DIRS = ["scripts"]
EXCLUDE_FILES = {"scripts/net/schema.gd"}  # generated, no logic to cover

BLOCK_CONTINUATIONS = ("elif ", "elif(", "else:", "else :")
DEFAULT_GODOT = "/Applications/Godot_mono_v4.7.2.app/Contents/MacOS/Godot"


def strip_comment(line):
    """Remove a trailing # comment, respecting quotes."""
    out, quote, i = [], None, 0
    while i < len(line):
        c = line[i]
        if quote:
            if c == "\\":
                out.append(line[i:i + 2]); i += 2; continue
            if c == quote:
                quote = None
        elif c in "\"'":
            quote = c
        elif c == "#":
            break
        out.append(c)
        i += 1
    return "".join(out)


def indent_of(line):
    return len(line) - len(line.lstrip("\t "))


class Instrumenter:
    def __init__(self, file_id, text):
        self.file_id = file_id
        self.lines = text.split("\n")
        self.covered = []          # original line numbers we instrumented
        self.declarations = 0      # class-level executable declarations, excluded
        self.out = []

    def _next_code_indent(self, start):
        """Indent of the next non-blank, non-comment line at or after `start`."""
        for j in range(start, len(self.lines)):
            stripped = strip_comment(self.lines[j]).strip()
            if stripped:
                return indent_of(self.lines[j])
        return None

    def run(self):
        depth = 0
        continued = False
        in_block_string = False
        func_indent = None
        stack = []                 # (indent, kind) for enclosing blocks
        skip_next_insert = False

        for index, raw in enumerate(self.lines):
            line_number = index + 1
            code = strip_comment(raw)
            stripped = code.strip()
            indent = indent_of(raw)

            triple_count = code.count('"""') + code.count("'''")
            was_in_block_string = in_block_string
            if triple_count % 2 == 1:
                in_block_string = not in_block_string

            is_statement_start = (
                not was_in_block_string
                and bool(stripped)
                and depth == 0
                and not continued
            )

            if is_statement_start:
                while stack and stack[-1][0] >= indent:
                    stack.pop()

                if stripped.startswith("func ") or stripped.startswith("static func ") \
                        or re.match(r"^func\s*\(", stripped):
                    func_indent = indent
                    stack = [(indent, "func")]
                elif func_indent is not None and indent <= func_indent:
                    func_indent = None

                inside_function = func_indent is not None and indent > func_indent

                if inside_function and not skip_next_insert:
                    parent_kind = stack[-1][1] if stack else None
                    is_continuation = stripped.startswith(BLOCK_CONTINUATIONS) \
                        or stripped in ("else:",) or parent_kind == "match"

                    if not is_continuation:
                        self.out.append("%sCovTracker.hit(%d, %d)" % ("\t" * indent, self.file_id, line_number))
                        self.covered.append(line_number)
                    elif stripped.endswith(":"):
                        # Cannot insert before `else:`/`elif`/a match pattern --
                        # record the branch from inside its own block instead.
                        body_indent = self._next_code_indent(index + 1)
                        if body_indent is not None and body_indent > indent:
                            self.out.append(raw)
                            self.out.append("%sCovTracker.hit(%d, %d)"
                                            % ("\t" * body_indent, self.file_id, line_number))
                            self.covered.append(line_number)
                            if stripped.endswith(":"):
                                stack.append((indent, "match" if stripped.startswith("match ") else "block"))
                            depth += code.count("(") + code.count("[") + code.count("{")
                            depth -= code.count(")") + code.count("]") + code.count("}")
                            depth = max(depth, 0)
                            continued = code.rstrip().endswith("\\")
                            skip_next_insert = False
                            continue
                elif not inside_function and stripped.startswith(("var ", "const ", "@onready")) and "=" in stripped:
                    self.declarations += 1

                skip_next_insert = stripped.startswith("@") and not stripped.startswith("@onready var")

                if stripped.endswith(":"):
                    stack.append((indent, "match" if stripped.startswith("match ") else "block"))

            self.out.append(raw)

            depth += code.count("(") + code.count("[") + code.count("{")
            depth -= code.count(")") + code.count("]") + code.count("}")
            depth = max(depth, 0)
            continued = code.rstrip().endswith("\\")

        return "\n".join(self.out)


def collect_sources():
    found = []
    for directory in SOURCE_DIRS:
        for dirpath, _dirs, files in os.walk(os.path.join(PROJECT, directory)):
            for name in sorted(files):
                if not name.endswith(".gd"):
                    continue
                absolute = os.path.join(dirpath, name)
                relative = os.path.relpath(absolute, PROJECT)
                if relative in EXCLUDE_FILES:
                    continue
                found.append(relative)
    return sorted(found)


TRACKER = '''extends Node

## Generated by tools/coverage.py -- records which instrumented lines ran.

var _hits: Array = []
var _manifest: Dictionary = {}


func _ready() -> void:
	var text := FileAccess.get_file_as_string("res://coverage_manifest.json")
	_manifest = JSON.parse_string(text)
	for entry in _manifest["files"]:
		var counts := PackedInt32Array()
		counts.resize(int(entry["line_count"]) + 2)
		_hits.append(counts)


func hit(file_id: int, line: int) -> void:
	_hits[file_id][line] += 1


func _exit_tree() -> void:
	flush()


func flush() -> void:
	var payload := []
	for counts in _hits:
		payload.append(Array(counts))
	var file := FileAccess.open("res://coverage_hits.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload))
		file.close()
'''


def build(sources):
    if os.path.exists(BUILD):
        shutil.rmtree(BUILD)
    os.makedirs(BUILD)

    for entry in os.listdir(PROJECT):
        if entry in {".godot", ".coverage", ".git"}:
            continue
        source = os.path.join(PROJECT, entry)
        target = os.path.join(BUILD, entry)
        if os.path.isdir(source):
            shutil.copytree(source, target, symlinks=True)
        else:
            shutil.copy2(source, target)

    manifest = {"files": []}
    for file_id, relative in enumerate(sources):
        text = open(os.path.join(PROJECT, relative), encoding="utf-8").read()
        instrumenter = Instrumenter(file_id, text)
        instrumented = instrumenter.run()
        with open(os.path.join(BUILD, relative), "w", encoding="utf-8") as handle:
            handle.write(instrumented)
        manifest["files"].append({
            "path": relative,
            "line_count": len(text.split("\n")),
            "lines": instrumenter.covered,
            "declarations": instrumenter.declarations,
        })

    with open(os.path.join(BUILD, "coverage_manifest.json"), "w") as handle:
        json.dump(manifest, handle)
    with open(os.path.join(BUILD, "cov_tracker.gd"), "w") as handle:
        handle.write(TRACKER)

    godot_project = os.path.join(BUILD, "project.godot")
    text = open(godot_project).read()
    text += '\n[autoload]\n\nCovTracker="*res://cov_tracker.gd"\n'
    open(godot_project, "w").write(text)

    return manifest


def run_tests(godot):
    subprocess.run([godot, "--headless", "--path", BUILD, "--import"],
                   capture_output=True, timeout=600)
    result = subprocess.run(
        [godot, "--headless", "--path", BUILD, "-s", "addons/gut/gut_cmdln.gd", "-gconfig=.gutconfig.json"],
        capture_output=True, text=True, timeout=1800)
    return result


def write_lcov(manifest, hits, path):
    lines = []
    for file_id, entry in enumerate(manifest["files"]):
        counts = hits[file_id] if file_id < len(hits) else []
        lines.append("SF:%s" % entry["path"])
        found = hit = 0
        for line_number in entry["lines"]:
            count = counts[line_number] if line_number < len(counts) else 0
            lines.append("DA:%d,%d" % (line_number, count))
            found += 1
            if count > 0:
                hit += 1
        lines.append("LF:%d" % found)
        lines.append("LH:%d" % hit)
        lines.append("end_of_record")
    open(path, "w").write("\n".join(lines) + "\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", default=os.environ.get("GODOT", DEFAULT_GODOT))
    parser.add_argument("--fail-under", type=float, default=0.0)
    parser.add_argument("--keep", action="store_true", help="keep the instrumented build tree")
    args = parser.parse_args()

    sources = collect_sources()
    print("instrumenting %d files" % len(sources))
    manifest = build(sources)

    print("running the suite against the instrumented copy ...")
    result = run_tests(args.godot)
    passed = "All tests passed" in result.stdout
    totals = re.search(r"Tests\s+(\d+)\n\s+Passing\s+(\d+)", result.stdout)
    if totals:
        print("  %s of %s tests passed" % (totals.group(2), totals.group(1)))
    if not passed:
        print("  WARNING: the instrumented suite did not report a clean pass")
        failing = [l for l in result.stdout.splitlines() if "Failed" in l or "Parse Error" in l]
        for line in failing[:20]:
            print("   ", line.strip())

    hits_path = os.path.join(BUILD, "coverage_hits.json")
    if not os.path.exists(hits_path):
        sys.exit("no coverage data was written -- the instrumented run did not complete")
    hits = json.load(open(hits_path))

    lcov_path = os.path.join(PROJECT, ".coverage", "lcov.info")
    write_lcov(manifest, hits, lcov_path)

    total_found = total_hit = total_declarations = 0
    rows = []
    for file_id, entry in enumerate(manifest["files"]):
        counts = hits[file_id] if file_id < len(hits) else []
        found = len(entry["lines"])
        hit = sum(1 for n in entry["lines"] if n < len(counts) and counts[n] > 0)
        missed = [n for n in entry["lines"] if not (n < len(counts) and counts[n] > 0)]
        total_found += found
        total_hit += hit
        total_declarations += entry["declarations"]
        rows.append((entry["path"], hit, found, missed))

    width = max(len(r[0]) for r in rows) + 2
    print("\n%-*s %8s %8s   %s" % (width, "file", "covered", "total", "uncovered lines"))
    print("-" * (width + 40))
    for path, hit, found, missed in rows:
        percent = (100.0 * hit / found) if found else 100.0
        shown = ", ".join(str(n) for n in missed[:10]) + (" ..." if len(missed) > 10 else "")
        print("%-*s %7d%% %8d   %s" % (width, path, round(percent), found, shown))

    overall = (100.0 * total_hit / total_found) if total_found else 100.0
    print("-" * (width + 40))
    print("%-*s %7.1f%% %8d   (%d/%d statements)" % (width, "TOTAL", overall, total_found, total_hit, total_found))
    print("\n%d class-level declarations excluded (not instrumentable)" % total_declarations)
    print("lcov written to %s" % os.path.relpath(lcov_path, PROJECT))

    if not args.keep:
        pass  # the build tree is small and useful for debugging; left in place

    if args.fail_under and overall < args.fail_under:
        sys.exit("coverage %.1f%% is below the required %.1f%%" % (overall, args.fail_under))


if __name__ == "__main__":
    main()
