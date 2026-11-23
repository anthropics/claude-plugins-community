#!/usr/bin/env python3
"""Exit 0 if every error in a failed "claude plugin validate" was there before.

  known-errors.py <head marketplace> <head output> <base marketplace> <base output> <rest>

An error counts as there before only if it is about one entry, that entry is
exactly the same in the base marketplace, and validating the base gave the same
error for it. Anything this cannot read is a new error (exit 1).

<rest> gets the head marketplace without those entries. The caller must validate
it too, in case the known errors keep the CLI from reporting others.
"""

import json
import re
import sys

HEADER = re.compile(r"^\S+ Found (\d+) errors?:\s*$")
ERROR = re.compile(r"^\s*❯ plugins\[(\d+)\](\S*): (.+)$")


def read_errors(marketplace, output):
    """{(entry as JSON, field, message)}, or None if the output is not understood."""
    with open(marketplace, encoding="utf-8") as f:
        plugins = json.load(f)["plugins"]
    with open(output, encoding="utf-8") as f:
        lines = f.read().split("\n")
    headers = [i for i, line in enumerate(lines) if HEADER.match(line)]
    if len(headers) != 1:
        return None
    found = []
    for line in lines[headers[0] + 1:]:
        if not line.strip():
            if found:
                break
            continue
        match = ERROR.match(line)
        if not match or int(match[1]) >= len(plugins):
            return None
        found.append((json.dumps(plugins[int(match[1])], sort_keys=True), match[2], match[3]))
    if len(found) != int(HEADER.match(lines[headers[0]])[1]):
        return None
    return found


def main():
    head = read_errors(sys.argv[1], sys.argv[2])
    base = read_errors(sys.argv[3], sys.argv[4])
    if not head or base is None:
        return 1
    before = set(base)
    new = [e for e in head if e not in before]
    # An entry listed twice is a new error of its own, even word for word.
    if new or any(head.count(e) > base.count(e) for e in set(head)):
        return 1
    known = {entry for entry, _, _ in head}
    with open(sys.argv[1], encoding="utf-8") as f:
        rest = json.load(f)
    rest["plugins"] = [p for p in rest["plugins"] if json.dumps(p, sort_keys=True) not in known]
    with open(sys.argv[5], "w", encoding="utf-8") as f:
        json.dump(rest, f)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        sys.exit(1)
