#!/usr/bin/env python3
"""Check module boundaries, generated loading units, and an optional release AAB."""
import argparse
import re
import sys
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FEATURES = {"edc_module": "edcComponent", "pulsa_module": "pulsaComponent"}
ANDROID = "{http://schemas.android.com/apk/res/android}"
DIST = "{http://schemas.android.com/apk/distribution}"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def check_sources():
    directives = re.compile(r"\b(import|export|part)\s+['\"]([^'\"]+)['\"]([^;]*);", re.S)
    for source in (ROOT / "lib").rglob("*.dart"):
        for kind, uri, modifiers in directives.findall(source.read_text()):
            if uri.startswith("dart:"):
                continue
            target = (ROOT / "lib" / uri.removeprefix("package:smart_pos/")) if uri.startswith("package:smart_pos/") else (source.parent / uri)
            target = target.resolve()
            for feature in FEATURES:
                directory = (ROOT / "lib/features" / feature).resolve()
                if target.is_relative_to(directory) and not source.resolve().is_relative_to(directory):
                    require(kind == "import" and re.search(r"\bdeferred\s+as\b", modifiers),
                            f"Eager dependency leaks {feature}: {source.relative_to(ROOT)} -> {uri}")
    pubspec = (ROOT / "pubspec.yaml").read_text()
    # Base assets must not duplicate component assets.
    base = pubspec.split("deferred-components:")[0]
    require("assets/edc_assets/" not in base and "assets/pulsa_assets/" not in base,
            "Feature assets must not be declared as base assets")
    app = ET.parse(ROOT / "android/app/src/main/AndroidManifest.xml").getroot().find("application")
    require(app.get(ANDROID + "name") == "io.flutter.embedding.android.FlutterPlayStoreSplitApplication",
            "Missing Flutter split application")
    for feature, component in FEATURES.items():
        require(f"name: {component}" in pubspec, f"Missing {component} in pubspec")
        entry = "edc_entry" if feature == "edc_module" else "pulsa_entry"
        require(f"package:smart_pos/features/{feature}/{entry}.dart" in pubspec,
                f"Missing deferred entry for {component}")
        manifest = ET.parse(ROOT / f"android/{component}/src/main/AndroidManifest.xml").getroot()
        require(manifest.find(f"{DIST}module/{DIST}delivery/{DIST}on-demand") is not None,
                f"{component} is not on-demand")
        gradle = (ROOT / f"android/{component}/build.gradle").read_text()
        require("deferred_assets" in gradle and "deferred_libs" in gradle,
                f"{component} is missing Flutter payload source sets")
    require(not list((ROOT / "android/app").rglob("*.aar")), "Vendor AAR leaked into base module")
    print("PASS: Dart boundaries, feature assets, Android split configuration")


def check_loading_units():
    path = ROOT / "deferred_components_loading_units.yaml"
    require(path.exists(), "Loading-unit baseline missing; run the Android release build")
    units = {}
    current = None
    for line in path.read_text().splitlines():
        match = re.match(r"\s*- id: (\d+)\s*$", line)
        if match:
            current = int(match[1])
            units[current] = []
        match = re.match(r"\s*- (package:\S+)\s*$", line)
        if match and current is not None:
            units[current].append(match[1])
    assigned = {}
    for feature, component in FEATURES.items():
        entry = "edc_entry" if feature == "edc_module" else "pulsa_entry"
        uri = f"package:smart_pos/features/{feature}/{entry}.dart"
        ids = [key for key, libraries in units.items() if uri in libraries]
        require(len(ids) == 1 and ids[0] > 1, f"{uri} has no unique deferred loading unit")
        assigned[component] = ids[0]
    require(len(set(assigned.values())) == len(FEATURES), "EDC and Pulsa share a loading unit")
    app = ET.parse(ROOT / "android/app/src/main/AndroidManifest.xml").getroot().find("application")
    key = "io.flutter.embedding.engine.deferredcomponents.DeferredComponentManager.loadingUnitMapping"
    metadata = next((node for node in app.findall("meta-data") if node.get(ANDROID + "name") == key), None)
    require(metadata is not None, "Base manifest has no loading-unit mapping")
    mapping = dict(item.split(":", 1) for item in metadata.get(ANDROID + "value", "").split(",") if ":" in item)
    for component, unit in assigned.items():
        require(mapping.get(str(unit)) == component, f"Manifest mapping is stale for {component}")
    print(f"PASS: separate generated loading units {assigned}")
    return assigned


def check_bundle(path, assigned):
    with zipfile.ZipFile(path) as bundle:
        names = bundle.namelist()
        for component, unit in assigned.items():
            require(any(name.startswith(f"{component}/lib/") and name.endswith(f"libapp.so-{unit}.part.so") for name in names),
                    f"{component} has no deferred Dart library for unit {unit}")
            directory = "edc_assets" if component == "edcComponent" else "pulsa_assets"
            require(any(name.startswith(f"{component}/assets/") and f"assets/{directory}/" in name for name in names),
                    f"{component} has no component assets")
            require(not any(name.startswith("base/") and (f"assets/{directory}/" in name or name.endswith(f"libapp.so-{unit}.part.so")) for name in names),
                    f"{component} payload leaked into base")
        require("base/manifest/AndroidManifest.xml" in names, "Not an Android app bundle")
    print("PASS: release AAB contains separate feature Dart libraries/assets; base excludes them")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--loading-units", action="store_true")
    parser.add_argument("--aab", type=Path)
    args = parser.parse_args()
    try:
        check_sources()
        if args.loading_units or args.aab:
            assigned = check_loading_units()
            if args.aab:
                check_bundle(args.aab, assigned)
    except (ValueError, OSError, ET.ParseError, zipfile.BadZipFile) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
