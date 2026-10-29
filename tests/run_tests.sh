#!/usr/bin/env bash
set -u

project="$(cd "$(dirname "$0")/.." && pwd)"
if [ "${1:-}" = "--project" ]; then
	project="$2"
	shift 2
fi
bins=("$@")
if [ ${#bins[@]} -eq 0 ]; then
	if [ -z "${GODOT_BIN:-}" ]; then
		echo "SETUP ERROR: GODOT_BIN is not set. Set GODOT_BIN to the Godot 4.7.x console binary or pass its path as an argument."
		exit 2
	fi
	bins=("$GODOT_BIN")
fi
for bin in "${bins[@]}"; do
	version="$(timeout 60 "$bin" --headless --version 2>/dev/null | tr -d '\r' | head -n 1)"
	if ! grep -qE "^4\.7\." <<<"$version"; then
		echo "SETUP ERROR: $bin reports '${version:-no version}', required Godot 4.7.x. Set GODOT_BIN to the Godot 4.7.x console binary."
		exit 2
	fi
done

status=0
for bin in "${bins[@]}"; do
	log="$(mktemp)"
	problems=""
	for step in "--import" "--check-only --script res://scripts/main.gd" "--check-only --script res://tests/test_core_loop.gd" "-s res://tests/test_core_loop.gd"; do
		timeout 300 "$bin" --headless --path "$project" $step >>"$log" 2>&1
		code=$?
		if [ $code -ne 0 ]; then
			problems="$problems [exit $code: $step]"
		fi
	done
	clean="$(tr -d '\r' <"$log")"
	if grep -qE "SCRIPT ERROR|^ERROR|Parse Error" <<<"$clean"; then
		problems="$problems [godot errors]"
	fi
	if grep -q "^FAIL" <<<"$clean"; then
		problems="$problems [failed checks]"
	fi
	if ! grep -qE "^ALL_TESTS_COMPLETED tests=[0-9]+ assertions=[0-9]+$" <<<"$clean"; then
		problems="$problems [completion marker missing]"
	fi
	echo "== $bin"
	grep -E "^Godot Engine|SCRIPT ERROR|^ERROR|Parse Error|^FAIL|^PASSED|^ALL_TESTS_COMPLETED" <<<"$clean"
	if [ -z "$problems" ]; then
		echo "RESULT: OK"
	else
		echo "RESULT: FAILED$problems"
		status=1
	fi
	rm -f "$log"
done
exit $status
