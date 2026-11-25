#!/bin/bash
# Runs the iOS gallery-flow UI tests on a booted simulator, then checks the
# crop each test saved: its shape and where the photo's red marker ended up.
#
# Usage: example/ios/RunnerUITests/run_gallery_tests.sh <simulator-udid>
set -uo pipefail

SIM="${1:?usage: $0 <simulator-udid>}"
HERE="$(cd "$(dirname "$0")" && pwd)"
IOS_DIR="$(dirname "$HERE")"
WORK="$(mktemp -d)"
APP_ID=com.example.example
RUNNER_ID=com.example.example.RunnerUITests.xctrunner
XCODEBUILD=(xcodebuild -workspace "$IOS_DIR/Runner.xcworkspace" -scheme Runner
            -destination "id=$SIM" -derivedDataPath "$WORK/DerivedData")
failures=0

echo "Work folder: $WORK"
swift "$HERE/tools/make_test_photo.swift" "$WORK/document.jpg" > /dev/null || exit 1
xcrun simctl addmedia "$SIM" "$WORK/document.jpg" || exit 1
swiftc -O "$HERE/tools/analyze_crop.swift" -o "$WORK/analyze_crop" || exit 1
echo "Building app and tests..."
"${XCODEBUILD[@]}" build-for-testing > "$WORK/build.log" 2>&1 || { echo "Build failed: $WORK/build.log"; exit 1; }

# Saved crops by file name; the app's data folder moves each time it is reinstalled.
crops() {
    local data
    data=$(xcrun simctl get_app_container "$SIM" "$APP_ID" data 2>/dev/null) || return 0
    ls -1 "$data/Library/" 2>/dev/null | grep '\.jpg$' | sort
}

fail() { echo "FAIL $1: $2"; failures=$((failures + 1)); }

# run_test <test name> <expectation: portrait-marker-top-left | landscape-marker-top-right | marker-cut-off | no-crop>
run_test() {
    local name=$1 expect=$2 before after new
    before=$(crops)
    if ! "${XCODEBUILD[@]}" test-without-building \
            -only-testing:"RunnerUITests/GalleryFlowUITests/$name" > "$WORK/$name.log" 2>&1; then
        fail "$name" "UI test failed, see $WORK/$name.log"
        grep -E "error: -\[|XCTAssert" "$WORK/$name.log" | head -3
        return
    fi
    after=$(crops)
    new=$(comm -13 <(echo "$before") <(echo "$after") | grep . || true)
    local count
    count=$(echo -n "$new" | grep -c . || true)

    if [ "$expect" = no-crop ]; then
        [ "$count" -eq 0 ] && echo "PASS $name: nothing saved" || fail "$name" "expected no crop, found $count"
        return
    fi
    [ "$count" -eq 1 ] || { fail "$name" "expected one new crop, found $count"; return; }
    cp "$(xcrun simctl get_app_container "$SIM" "$APP_ID" data)/Library/$new" "$WORK/$name.jpg"
    read -r w h tl tr bl br < <("$WORK/analyze_crop" "$WORK/$name.jpg")
    local summary="${w}x${h}, red pixels TL=$tl TR=$tr BL=$bl BR=$br"
    local total=$((tl + tr + bl + br))
    case $expect in
        portrait-marker-top-left)
            [ "$h" -gt "$w" ] && [ "$tl" -gt 1000 ] && [ "$tl" -gt $((20 * (total - tl + 1))) ] ;;
        landscape-marker-top-right)
            [ "$w" -gt "$h" ] && [ "$tr" -gt 1000 ] && [ "$tr" -gt $((20 * (total - tr + 1))) ] ;;
        marker-cut-off)
            [ "$total" -lt 200 ] ;;
    esac && echo "PASS $name: $summary" || fail "$name" "unexpected crop: $summary"
}

run_test test1_pickAndDone        portrait-marker-top-left
run_test test2_pickRotateDone     landscape-marker-top-right
run_test test3_pickDragCornerDone marker-cut-off
run_test test4_cancelInPicker     no-crop
run_test test5_cancelInEditor     no-crop

# Screenshot of the Flutter app showing the first test's result.
runner_data=$(xcrun simctl get_app_container "$SIM" "$RUNNER_ID" data 2>/dev/null) &&
    find "$runner_data" -name "gallery-after-done.png" -exec cp {} "$WORK/" \; 2>/dev/null
echo "Crops and screenshot: $WORK"
[ "$failures" -eq 0 ] && echo "ALL PASSED" || echo "$failures FAILED"
exit "$failures"
