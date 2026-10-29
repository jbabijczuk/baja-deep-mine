#!/usr/bin/env bash
set -u

here="$(cd "$(dirname "$0")" && pwd)"
project="$(cd "$here/.." && pwd)"
bins=("$@")
if [ ${#bins[@]} -eq 0 ]; then
	bins=("${GODOT_BIN:-}")
fi
count=${#bins[@]}

for bin in "${bins[@]}"; do
	if ! timeout 60 "$bin" --headless --version 2>/dev/null | tr -d '\r' | grep -qE "^4\.7\."; then
		echo "SETUP ERROR: Godot 4.7.x not runnable: $bin. Set GODOT_BIN to the Godot 4.7.x console binary."
		exit 2
	fi
done

prepare_copy() {
	local copy="$1"
	local case_name="$2"
	cp -r "$project/project.godot" "$project/data" "$project/scenes" "$project/scripts" "$project/tests" "$copy/"
	sed -i 's/^config\/name=.*/config\/name="Deep Mine Runner Selfcheck"/' "$copy/project.godot"
	python - "$copy/tests/test_core_loop.gd" "$case_name" <<'EOF'
import sys
path, case = sys.argv[1], sys.argv[2]
s = open(path, encoding="utf-8").read()
anchor = "func _test_upgrade() -> bool:\n"
if case in ("runtime_error", "runtime_error_exit_zero"):
    s = s.replace(anchor, anchor + "\tvar injected = null\n\tinjected.missing_method()\n", 1)
if case == "runtime_error_exit_zero":
    s = s.replace("quit(1 if failures > 0 else 0)", "quit(0)")
if case == "missing_assertion":
    s = s.replace('\t_check(g.training == 2, "training upgrade bought")\n', "", 1)
open(path, "w", encoding="utf-8", newline="\n").write(s)
EOF
}

run_case() {
	local case_name="$1"
	local copy
	copy="$(mktemp -d)"
	prepare_copy "$copy" "$case_name"
	bash "$here/run_tests.sh" --project "$copy" "${bins[@]}" >"$copy/runner.log" 2>&1
	runner_code=$?
	runner_log="$(tr -d '\r' <"$copy/runner.log")"
	rm -rf "$copy"
}

lines() {
	grep -cxF -- "$1" <<<"$runner_log"
}

matches() {
	grep -cE -- "$1" <<<"$runner_log"
}

status=0
expect() {
	local label="$1"
	local cond="$2"
	if [ "$cond" = "1" ]; then
		echo "PASS $label"
	else
		echo "FAIL $label"
		status=1
	fi
}

is() {
	[ "$1" = "$2" ] && echo 1 || echo 0
}

launch_clean() {
	[ "$(matches '^Godot Engine v4\.')" -ge "$count" ] && [ "$(matches 'exit 12[67]|command not found|No such file|Permission denied')" = "0" ] && echo 1 || echo 0
}

run_case control
expect "control: runner exit 0" "$(is "$runner_code" 0)"
expect "control: godot launched cleanly" "$(launch_clean)"
expect "control: 19 tests, 107 assertions on every binary" "$(is "$(lines 'ALL_TESTS_COMPLETED tests=19 assertions=107')" "$count")"
expect "control: RESULT OK on every binary" "$(is "$(lines 'RESULT: OK')" "$count")"
if [ $status -ne 0 ]; then
	echo "$runner_log"
	echo "SELFCHECK ABORTED: control run failed"
	exit 1
fi

run_case runtime_error
expect "runtime error: runner exit 1" "$(is "$runner_code" 1)"
expect "runtime error: godot launched cleanly" "$(launch_clean)"
expect "runtime error: script error reported" "$([ "$(matches '^SCRIPT ERROR')" -ge "$count" ] && echo 1 || echo 0)"
expect "runtime error: _test_upgrade not completed" "$(is "$(lines 'FAIL test not completed: _test_upgrade')" "$count")"
expect "runtime error: failure attributed" "$(is "$(lines 'RESULT: FAILED [exit 1: -s res://tests/test_core_loop.gd] [godot errors] [failed checks] [completion marker missing]')" "$count")"

run_case runtime_error_exit_zero
expect "forced exit 0: runner exit 1" "$(is "$runner_code" 1)"
expect "forced exit 0: godot launched cleanly" "$(launch_clean)"
expect "forced exit 0: _test_upgrade not completed" "$(is "$(lines 'FAIL test not completed: _test_upgrade')" "$count")"
expect "forced exit 0: godot exit 0 caught by output checks" "$(is "$(lines 'RESULT: FAILED [godot errors] [failed checks] [completion marker missing]')" "$count")"

run_case missing_assertion
expect "missing assertion: runner exit 1" "$(is "$runner_code" 1)"
expect "missing assertion: godot launched cleanly" "$(launch_clean)"
expect "missing assertion: count mismatch reported" "$(is "$(lines 'FAIL assertion count 106, expected 107')" "$count")"
expect "missing assertion: no script error" "$(is "$(matches 'SCRIPT ERROR')" 0)"
expect "missing assertion: failure attributed" "$(is "$(lines 'RESULT: FAILED [exit 1: -s res://tests/test_core_loop.gd] [failed checks] [completion marker missing]')" "$count")"

if [ $status -eq 0 ]; then
	echo "SELFCHECK OK"
else
	echo "SELFCHECK FAILED"
fi
exit $status
