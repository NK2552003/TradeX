#!/usr/bin/env python3
"""Finds Flutter layout overflow risks by walking widget constructor nesting.

A Row lays its children out at their intrinsic width and clips (with a yellow
overflow stripe) when they do not fit. Text, Column and Wrap all report an
intrinsic width equal to their unwrapped content, so any of them sitting as a
DIRECT child of a Row without Expanded/Flexible around it is an overflow waiting
for a long string. This walks the paren nesting to find exactly those, which grep
cannot do.
"""

import re
import sys
from pathlib import Path

# Widgets whose intrinsic width follows their content, so a Row cannot bound them.
GREEDY = {"Text", "Column", "Wrap", "RichText", "SelectableText", "ListView", "Row"}
# Wrappers that give a child a bounded width inside a Row.
BOUNDED = {
    "Expanded", "Flexible", "SizedBox", "ConstrainedBox", "Container",
    "LimitedBox", "FittedBox", "IntrinsicWidth", "Spacer",
}


def strip_noise(src: str) -> str:
    """Blank out comments and string bodies so their parens do not affect nesting."""
    out = []
    i, n = 0, len(src)
    while i < n:
        two = src[i : i + 2]
        if two == "//":
            j = src.find("\n", i)
            j = n if j < 0 else j
            out.append(" " * (j - i))
            i = j
            continue
        if two == "/*":
            j = src.find("*/", i + 2)
            j = n if j < 0 else j + 2
            out.append("".join(c if c == "\n" else " " for c in src[i:j]))
            i = j
            continue
        if src[i] in "'\"":
            quote = src[i]
            triple = src[i : i + 3] == quote * 3
            close = quote * 3 if triple else quote
            j = i + len(close)
            while j < n:
                if src[j] == "\\":
                    j += 2
                    continue
                if src[j : j + len(close)] == close:
                    j += len(close)
                    break
                j += 1
            out.append("".join(c if c == "\n" else " " for c in src[i:j]))
            i = j
            continue
        out.append(src[i])
        i += 1
    return "".join(out)


CALL = re.compile(r"\b([A-Z][A-Za-z0-9_]*)\s*(?:<[^<>()]*>\s*)?\(")


def find_calls(src: str):
    """Yield (name, open_paren_index, close_paren_index) for every ClassName( call."""
    for m in CALL.finditer(src):
        open_at = m.end() - 1
        depth, i, n = 0, open_at, len(src)
        while i < n:
            c = src[i]
            if c in "([{":
                depth += 1
            elif c in ")]}":
                depth -= 1
                if depth == 0:
                    yield m.group(1), open_at, i
                    break
            i += 1


def split_top_level(src: str):
    """Split a bracket body on top-level commas, yielding (text, offset)."""
    parts, depth, start = [], 0, 0
    for i, c in enumerate(src):
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        elif c == "," and depth == 0:
            parts.append((src[start:i], start))
            start = i + 1
    parts.append((src[start:], start))
    return parts


def children_of(src: str, open_at: int, close_at: int):
    """Yield (text, absolute_offset) for each entry of this call's children: list."""
    body = src[open_at + 1 : close_at]
    for arg, arg_off in split_top_level(body):
        key = arg.lstrip()
        pad = len(arg) - len(key)
        if not (key.startswith("children:") or key.startswith("children :")):
            continue
        rest = key[key.index(":") + 1 :]
        base = open_at + 1 + arg_off + pad + key.index(":") + 1
        lb = rest.find("[")
        if lb < 0:
            continue
        depth, i = 0, lb
        while i < len(rest):
            if rest[i] in "([{":
                depth += 1
            elif rest[i] in ")]}":
                depth -= 1
                if depth == 0:
                    break
            i += 1
        inner = rest[lb + 1 : i]
        for child, child_off in split_top_level(inner):
            if child.strip():
                yield child, base + lb + 1 + child_off


def first_widget(text: str) -> str:
    """The outermost widget name in a child expression, skipping const/if/spreads."""
    t = text.strip()
    for prefix in ("const ", "if (", "for (", "...", "?", ":"):
        if t.startswith(prefix):
            t = t[len(prefix) :].lstrip()
    m = re.match(r"([A-Z][A-Za-z0-9_]*)\s*(?:<[^<>()]*>\s*)?\(", t)
    return m.group(1) if m else ""


def audit(path: Path):
    raw = path.read_text()
    src = strip_noise(raw)
    line_of = [0] * (len(src) + 1)
    line = 1
    for i, c in enumerate(src):
        line_of[i] = line
        if c == "\n":
            line += 1
    line_of[len(src)] = line

    hits = []
    for name, open_at, close_at in find_calls(src):
        if name != "Row":
            continue
        for child, off in children_of(src, open_at, close_at):
            widget = first_widget(child)
            if widget in GREEDY and widget not in BOUNDED:
                snippet = " ".join(raw[off : off + 60].split())
                hits.append((line_of[off], widget, snippet))
    return hits


def main():
    roots = [Path(p) for p in sys.argv[1:]] or [Path("lib")]
    total = 0
    for root in roots:
        for path in sorted(root.rglob("*.dart")):
            hits = audit(path)
            if not hits:
                continue
            print(f"\n{path}")
            for ln, widget, snippet in hits:
                print(f"  {ln:>5}  {widget:<14} {snippet}")
                total += 1
    print(f"\n{total} unbounded Row children across {len(roots)} root(s)")


if __name__ == "__main__":
    main()
