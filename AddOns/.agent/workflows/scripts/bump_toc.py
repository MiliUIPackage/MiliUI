#!/usr/bin/env python3
"""Bump the ## Interface: version across every retail WoW addon TOC in a folder.

Dry run by default — nothing is written until you pass --apply.

    python3 bump_toc.py --target 120100 --dir "/path/to/Interface/AddOns"
    python3 bump_toc.py --target 120100 --dir "..." --apply

See SKILL.md for the reasoning behind the retail/classic split and the
add-vs-replace choice.
"""

import argparse
import glob
import os
import re
import sys

# Filename suffixes that mark a TOC as belonging to a non-retail client.
# Those files must keep their own Interface numbers — a retail version in a
# Vanilla TOC makes the addon unloadable there.
NON_RETAIL_FILE = re.compile(
    r'[_-](Vanilla|Classic|BCC|TBC|Wrath|WOTLKC|Cata|Mists|MoP)\.toc$', re.I
)

# "## Interface:" or the flavor-specific "## Interface-Mainline:" form.
INTERFACE_LINE = re.compile(
    r'^(##\s*Interface(?:-(?P<flavor>\w+))?\s*:\s*)(?P<vals>.*?)(?P<cr>\r?)$',
    re.M | re.I,
)

RETAIL_FLAVORS = {"mainline", "retail", "standard"}


def is_retail(token):
    """Retail interface numbers are 6 digits (100000+); classic ones are 5.

    This is the load-bearing distinction. 11508 is Classic Era 1.15.8, NOT
    retail 11.5.8 — comparing numerically without checking the digit count
    silently corrupts multi-flavor TOCs.
    """
    return bool(re.fullmatch(r'\d{6}', token))


def process_file(path, target, mode):
    """Return (status, old_values, new_values). Nothing is written here."""
    if NON_RETAIL_FILE.search(os.path.basename(path)):
        return "skip-flavor-file", None, None

    with open(path, "rb") as fh:
        data = fh.read()
    bom = data.startswith(b'\xef\xbb\xbf')
    text = data.decode("utf-8-sig")

    m = INTERFACE_LINE.search(text)
    if not m:
        return "no-interface-line", None, None

    flavor = (m.group("flavor") or "").lower()
    if flavor and flavor not in RETAIL_FLAVORS:
        return "skip-flavor-directive", m.group("vals"), None

    toks = [t.strip() for t in m.group("vals").split(",") if t.strip()]
    retail_idx = [i for i, t in enumerate(toks) if is_retail(t)]
    if not retail_idx:
        return "no-retail-version", m.group("vals"), None
    if target in toks and mode == "add":
        return "already", m.group("vals"), None

    if mode == "replace":
        # Keep the classic entries where they are, collapse every retail entry
        # into the single target, positioned where the first retail one was.
        new_toks = [t for i, t in enumerate(toks) if i not in set(retail_idx)]
        new_toks.insert(retail_idx[0], target)
    else:
        new_toks = list(toks)
        new_toks.insert(retail_idx[-1] + 1, target)

    if new_toks == toks:
        return "already", m.group("vals"), None

    new_vals = ", ".join(new_toks)
    new_line = m.group(1) + new_vals + m.group("cr")
    new_text = text[:m.start()] + new_line + text[m.end():]

    out = new_text.encode("utf-8")
    if bom:
        out = b'\xef\xbb\xbf' + out
    return ("change", m.group("vals"), new_vals), out, path


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--target", required=True,
                    help="Interface version to add, e.g. 120100 for patch 12.1.0")
    ap.add_argument("--dir", default=".",
                    help="AddOns folder (default: current directory)")
    ap.add_argument("--mode", choices=["add", "replace"], default="add",
                    help="add: keep existing retail versions alongside the target "
                         "(default, safest). replace: collapse all retail versions "
                         "into the target only.")
    ap.add_argument("--apply", action="store_true",
                    help="actually write the files (default is a dry run)")
    args = ap.parse_args()

    if not re.fullmatch(r'\d{6}', args.target):
        sys.exit("--target must be a 6-digit retail interface number "
                 "(XYYZZ + leading digits), e.g. 120100 for 12.1.0")

    root = os.path.abspath(args.dir)
    if not os.path.isdir(root):
        sys.exit("no such directory: " + root)

    paths = sorted(glob.glob(os.path.join(root, "*", "*.toc")))
    if not paths:
        sys.exit("found no */*.toc under " + root +
                 "\n(point --dir at the AddOns folder itself)")

    buckets = {}
    writes = []
    for path in paths:
        rel = os.path.relpath(path, root)
        result = process_file(path, args.target, args.mode)
        status = result[0]
        if isinstance(status, tuple):  # ("change", old, new)
            _, old, new = status
            buckets.setdefault("change", []).append((rel, old, new))
            writes.append((path, result[1]))
        else:
            buckets.setdefault(status, []).append((rel, result[1]))

    changes = buckets.get("change", [])
    print("=== will change (%d) ===" % len(changes))
    for rel, old, new in changes:
        print("  %-56s %s  ->  %s" % (rel, old, new))

    labels = [
        ("already", "already has %s" % args.target),
        ("skip-flavor-file", "skipped: non-retail flavor TOC"),
        ("skip-flavor-directive", "skipped: non-retail Interface-<flavor> directive"),
        ("no-retail-version", "skipped: no retail (6-digit) version present"),
        ("no-interface-line", "skipped: no Interface line at all"),
    ]
    for key, label in labels:
        rows = buckets.get(key, [])
        if not rows:
            continue
        print("\n=== %s (%d) ===" % (label, len(rows)))
        for rel, vals in rows:
            print("  %s%s" % (rel, ("  ->  " + vals) if vals else ""))

    total = sum(len(v) for v in buckets.values())
    print("\n%d TOC files seen, all accounted for." % total)

    if args.apply:
        for path, blob in writes:
            with open(path, "wb") as fh:
                fh.write(blob)
        print("APPLIED — %d files written." % len(writes))
        print("Verify with: git diff --shortstat -- '*.toc'")
    else:
        print("DRY RUN — nothing written. Re-run with --apply to commit the changes.")


if __name__ == "__main__":
    main()
