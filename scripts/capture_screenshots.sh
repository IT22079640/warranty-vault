#!/bin/zsh
# Runs ScreenshotTourTests on the iPhone 16 simulator and writes named images to docs/screenshots.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/docs/screenshots"
RESULT="${TMPDIR:-/tmp}/WarrantyVaultScreenshotTour.xcresult"
EXPORT="$(mktemp -d)"

cleanup() {
  rm -rf "$EXPORT"
}
trap cleanup EXIT

# Picks the newest iOS runtime that has a device named exactly "iPhone 16".
DESTINATION="$(python3 - << 'PY'
import json, subprocess, sys
raw = subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"])
devices = json.loads(raw)["devices"]
found = []
for runtime, entries in devices.items():
    if "iOS-" not in runtime:
        continue
    version = runtime.split("iOS-", 1)[1].replace("-", ".")
    for device in entries:
        if device.get("name") == "iPhone 16" and device.get("isAvailable", True):
            found.append(version)
if not found:
    sys.exit("No available simulator is named exactly 'iPhone 16'.")
found.sort(key=lambda value: [int(part) for part in value.split(".")])
print(f"platform=iOS Simulator,name=iPhone 16,OS={found[-1]}")
PY
)"

echo "Destination: $DESTINATION"
mkdir -p "$OUT"
rm -rf "$RESULT"
find "$OUT" -maxdepth 1 -name '*.png' -delete

set +e
xcodebuild \
  -project "$ROOT/WarrantyVault.xcodeproj" \
  -scheme WarrantyVault \
  -destination "$DESTINATION" \
  -parallel-testing-enabled NO \
  -only-testing:WarrantyVaultUITests/ScreenshotTourTests \
  -resultBundlePath "$RESULT" \
  test
test_status=$?
set -e

xcrun xcresulttool export attachments \
  --path "$RESULT" \
  --output-path "$EXPORT"

python3 - "$EXPORT" "$OUT" << 'PY'
import json, re, shutil, struct, subprocess, sys
from pathlib import Path

export = Path(sys.argv[1])
out = Path(sys.argv[2])
manifest = json.loads((export / "manifest.json").read_text())

captions = {
    "01_onboarding_page1": "Introduction, page 1. Every warranty in one place.",
    "02_onboarding_page2": "Introduction, page 2. Import a receipt from Photos or Files.",
    "03_onboarding_page3": "Introduction, page 3. Reminders 30, 7, and 1 day before cover ends.",
    "04_vault_empty": "Vault with nothing saved yet.",
    "05_vault_list": "Seeded vault in the list layout. Active Lamp and Expired Fan.",
    "06_vault_grid": "Seeded vault in the grid layout.",
    "07_vault_search": "Vault search limited to Lamp.",
    "08_vault_filter_all": "All-warranties filter.",
    "09_vault_filter_active": "Active filter. Expired Fan is hidden.",
    "10_vault_filter_expiring": "Expiring-soon filter. Neither seeded warranty is inside 30 days.",
    "11_vault_filter_expired": "Expired filter. Expired Fan is the only row.",
    "12_vault_swipe": "Swipe actions for archive and delete.",
    "13_vault_context_menu": "Context menu with view, edit, archive, and delete.",
    "14_item_detail": "Warranty detail, including the receipt photo.",
    "15_item_detail_zoomed": "Receipt photo after a double tap to zoom.",
    "16_edit_form": "Edit form filled from the saved warranty.",
    "17_add_tab": "Add tab, before a receipt is chosen.",
    "18_add_scanning": "OCR scanning state over the bundled sample receipt.",
    "19_add_review_form": "Review form. Amber marks values the parser was not sure about.",
    "20_add_recognized_text": "Recognized text read from the sample receipt.",
    "21_add_validation_errors": "Manual entry after Save, with the required fields empty.",
    "22_insights": "Insights charts for the seeded vault.",
    "23_insights_empty": "Insights before any warranty is saved.",
    "24_settings": "Settings: reminders, appearance, export, and about.",
    "25_settings_appearance": "Appearance override set to the opposite of the launch style.",
    "26_settings_clear_confirmation": "Confirmation before clearing every warranty.",
}

styles = {
    "light_portrait": "Light, portrait",
    "dark_portrait": "Dark, portrait",
    "light_landscape": "Light, landscape",
    "dark_landscape": "Dark, landscape",
    "light_portrait_accessibility": "Light, portrait, largest accessibility text",
}

def png_is_portrait(path: Path) -> bool:
    width, height = struct.unpack(">II", path.read_bytes()[16:24])
    return height > width

def attachments(node):
    if isinstance(node, dict):
        if "exportedFileName" in node and "suggestedHumanReadableName" in node:
            yield node
        for value in node.values():
            yield from attachments(value)
    elif isinstance(node, list):
        for item in node:
            yield from attachments(item)

saved = {}
for item in attachments(manifest):
    if item.get("isAssociatedWithFailure"):
        continue
    raw_name = item["suggestedHumanReadableName"]
    # xcresulttool appends "_0_<uuid>" and may include the file extension.
    stem = Path(raw_name).stem
    stem = re.sub(r"_\d+_[0-9A-Fa-f-]{36}$", "", stem)
    matched_style = next((style for style in styles if stem.endswith("_" + style)), None)
    if matched_style is None:
        continue
    prefix = stem[: -(len(matched_style) + 1)]
    if prefix not in captions:
        continue
    source = next(export.rglob(item["exportedFileName"]), None)
    if source is None:
        continue
    destination = out / f"{stem}{source.suffix.lower()}"
    shutil.copy2(source, destination)
    if matched_style in ("light_landscape", "dark_landscape") and png_is_portrait(destination):
        # Some simulator captures keep a portrait pixel buffer after the interface rotates.
        subprocess.run(["sips", "-r", "270", str(destination)], check=True, stdout=subprocess.DEVNULL)
    saved[destination.name] = prefix

for path in out.glob("*.png"):
    matched_style = next((style for style in styles if path.stem.endswith("_" + style)), None)
    if matched_style is None:
        continue
    prefix = path.stem[: -(len(matched_style) + 1)]
    if prefix in captions:
        saved[path.name] = prefix

lines = [
    "# Screenshot tour",
    "",
    "Captured by `ScreenshotTourTests` on an iPhone 16 simulator.",
    "Run `scripts/capture_screenshots.sh` to refresh these files.",
    "",
]
for style, heading in styles.items():
    lines.append(f"## {heading}")
    lines.append("")
    lines.append("| Screenshot | Caption |")
    lines.append("| --- | --- |")
    for prefix, caption in captions.items():
        matches = [file_name for file_name, key in saved.items() if key == prefix and f"_{style}." in file_name]
        if matches:
            lines.append(f"| `{matches[0]}` | {caption} |")
        else:
            lines.append(f"| `{prefix}_{style}.png` | {caption} Not captured. |")
    lines.append("")

(out / "INDEX.md").write_text("\n".join(lines) + "\n")
print(f"Wrote {len(saved)} screenshots to {out}")
raise SystemExit(0 if len(saved) else 1)
PY

exit "$test_status"
