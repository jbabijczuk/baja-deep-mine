$repo = 'jbabijczuk/baja-deep-mine'
$owner = 'jbabijczuk'
$lock = 'C:/Users/jbabi/orca/workspaces/BajaDeepMine/orca-queue.lock'

if (Test-Path -LiteralPath $lock) {
    Write-Output ('precheck: busy, lock present: ' + $lock)
    exit 2
}

$running = & gh issue list --repo $repo --state open --label orca-running --limit 50 --json number -q 'length'
if ($LASTEXITCODE -ne 0) {
    Write-Output 'precheck: gh error while reading orca-running'
    exit 3
}
if ([int]$running -gt 0) {
    Write-Output ('precheck: busy, orca-running issues: ' + $running)
    exit 2
}

$ready = & gh issue list --repo $repo --state open --label orca-ready --author $owner --limit 50 --json number -q 'length'
if ($LASTEXITCODE -ne 0) {
    Write-Output 'precheck: gh error while reading orca-ready'
    exit 3
}
if ([int]$ready -eq 0) {
    Write-Output 'precheck: queue empty'
    exit 1
}

Write-Output ('precheck: ready issues: ' + $ready)
exit 0
