#!/usr/bin/env bash
set -u

here="$(cd "$(dirname "$0")" && pwd)"
project="$(cd "$here/.." && pwd)"
status=0

run_case() {
	local label="$1"
	local script="$2"
	shift 2
	local copy
	copy="$(mktemp -d)"
	cp -r "$project/project.godot" "$project/data" "$project/scenes" "$project/scripts" "$project/tests" "$copy/"
	sed -i 's/^config\/name=.*/config\/name="Deep Mine Runner Selfcheck"/' "$copy/project.godot"
	python - "$copy/tests/test_core_loop.gd" "$script" <<'EOF'
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
	"$here/run_tests.sh" --project "$copy" "$@" >"$copy/runner.log" 2>&1
	local code=$?
	if [ $code -ne 0 ]; then
		echo "PASS $label: runner failed as expected ($(grep '^RESULT' "$copy/runner.log" | head -1))"
	else
		echo "FAIL $label: runner reported success"
		status=1
	fi
	rm -rf "$copy"
}

run_case "runtime error in test" runtime_error "$@"
run_case "runtime error with forced exit 0" runtime_error_exit_zero "$@"
run_case "missing assertion" missing_assertion "$@"
exit $status
