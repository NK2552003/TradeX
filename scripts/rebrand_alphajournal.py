"""Apply the alphajournal display and domain rebrand to editable sources.

Run from any directory: python3 scripts/rebrand_alphajournal.py --write
Use --check in CI to find old names in active sources. Historical migrations,
package names, OAuth schemes and repository URLs are intentionally preserved;
changing those requires a compatibility migration and store configuration.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCAN_ROOTS = (
    "lib", "assets", "database", "docs", "web", "android", "ios",
    "macos", "linux", "windows", "supabase", "test", "scripts",
)
EXTENSIONS = {
    ".dart", ".json", ".sql", ".md", ".py", ".mjs", ".ts", ".html",
    ".xml", ".plist", ".xcconfig", ".kt", ".cc", ".cpp", ".rc",
    ".yaml", ".dbml", ".txt",
}
SKIP_PARTS = {".git", "build", ".dart_tool", "node_modules", "Pods"}
OLD = "hejournal.in"
BRAND = "alphajournal"
DOMAIN = "alphajournal.in"


def active_files() -> list[Path]:
    result = []
    for name in SCAN_ROOTS:
        root = ROOT / name
        if not root.exists():
            continue
        for path in root.rglob("*"):
            if not path.is_file() or path.suffix not in EXTENSIONS:
                continue
            if any(part in SKIP_PARTS for part in path.parts):
                continue
            if path.is_relative_to(ROOT / "database/migrations"):
                continue
            if path.name.startswith(".env") or path == Path(__file__).resolve():
                continue
            result.append(path)
    result.extend([ROOT / name for name in ("README.md", "implementation.md", "pubspec.yaml")])
    return sorted(set(result))


def change(path: Path, contents: str) -> str:
    # Preserve the domain only where it is a network identifier. Elsewhere
    # the product's visible name is alphajournal without a domain suffix.
    contents = contents.replace("https://hejournal.in", f"https://{DOMAIN}")
    contents = contents.replace("http://hejournal.in", f"http://{DOMAIN}")
    contents = contents.replace("@hejournal.in", f"@{DOMAIN}")
    contents = contents.replace("www.hejournal.in", f"www.{DOMAIN}")
    if path.relative_to(ROOT).as_posix() in {
        "lib/core/linking/link_graph.dart",
        "docs/publication_pack/generate_documents.py",
    }:
        contents = contents.replace("'hejournal.in'", f"'{DOMAIN}'")
        contents = contents.replace('DOMAIN = "hejournal.in"', f'DOMAIN = "{DOMAIN}"')
    contents = contents.replace(OLD, BRAND)
    contents = contents.replace("hejournal_business", "alphajournal_business")
    contents = contents.replace(
        "HEJOURNAL_BILLING_AND_PUBLICATION", "ALPHAJOURNAL_BILLING_AND_PUBLICATION"
    )

    relative = path.relative_to(ROOT).as_posix()
    if relative in {
        "assets/data/landing_page.json",
        "database/seeds/03_public_site.sql",
        "database/seeds/02_demo_data.sql",
        "database/schema.sql",
        "database/erd.dbml",
        "implementation.md",
        "scripts/seed_live_existing_tables.mjs",
        "scripts/workspace_ui_gallery.py",
        "test/features/community_and_messages_live_test.dart",
        "test/features/ai_assistant/ai_assistant_overlay_sheet_test.dart",
        "test/features/community/community_layout_edit_regression_test.dart",
    }:
        contents = contents.replace("TradeX", BRAND)
    if relative == "README.md":
        contents = contents.replace("# TradeX App Scaffold", "# alphajournal App Scaffold")
    if relative == "pubspec.yaml":
        contents = contents.replace("TradeX Flutter project.", "alphajournal Flutter project.")
    if relative == "web/manifest.json":
        contents = contents.replace("TradeX", BRAND)
    if relative == "linux/runner/my_application.cc":
        contents = contents.replace('"TradeX"', f'"{BRAND}"')
    if relative == "windows/runner/main.cpp":
        contents = contents.replace('L"TradeX"', f'L"{BRAND}"')
    if relative == "windows/runner/Runner.rc":
        contents = contents.replace('"FileDescription", "TradeX"', f'"FileDescription", "{BRAND}"')
        contents = contents.replace('"ProductName", "TradeX"', f'"ProductName", "{BRAND}"')
    if relative == "lib/features/auth/presentation/widgets/tradex_footer.dart":
        contents = contents.replace("TradeX connects via", "alphajournal connects via")
    return contents


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--write", action="store_true", help="apply the rebrand")
    group.add_argument("--check", action="store_true", help="report stale active names")
    args = parser.parse_args()
    changed = []
    for path in active_files():
        original = path.read_text(encoding="utf-8")
        updated = change(path, original)
        if original != updated:
            changed.append(path.relative_to(ROOT).as_posix())
            if args.write:
                path.write_text(updated, encoding="utf-8")
    if args.write:
        for name in ("assets/data/landing_page.json", "assets/data/pricing_catalogue.json", "web/manifest.json"):
            json.loads((ROOT / name).read_text(encoding="utf-8"))
    for path in changed:
        print(path)
    print(f"{len(changed)} active files {'updated' if args.write else 'still need updating'}")
    if args.check and changed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
