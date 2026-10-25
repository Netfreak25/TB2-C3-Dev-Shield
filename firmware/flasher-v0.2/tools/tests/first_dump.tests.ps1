# Offline regression tests. The fake programmer never opens a serial port.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$runner = (Resolve-Path (Join-Path $PSScriptRoot '..\first_dump.ps1')).Path
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('tb2-c3-first-dump-tests-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
$fake = Join-Path $testRoot 'fake-flashrom.ps1'

@'
$counterPath = $env:TB2_FAKE_COUNTER
$number = if (Test-Path -LiteralPath $counterPath) { [int](Get-Content -LiteralPath $counterPath -Raw) + 1 } else { 1 }
Set-Content -LiteralPath $counterPath -Value $number -NoNewline

if ($args -contains '-w' -or $args -contains '-E') { throw 'A write or erase command reached fake flashrom.' }
$programmerIndex = [array]::IndexOf($args, '-p')
if ($programmerIndex -lt 0) { throw 'Missing programmer argument.' }
$requestedHz = if ($args[$programmerIndex + 1] -match 'spispeed=250k') { 250000 } else { 500000 }
$actualHz = if ($env:TB2_FAKE_MODE -eq 'clock-high') { 8000000 } else { $requestedHz }
$adapter = if ($env:TB2_FAKE_MODE -eq 'wrong-adapter') { 'pico-serprog' } else { 'tb2-c3-serprog' }
$chip = if ($env:TB2_FAKE_MODE -eq 'wrong-chip') { 'W25Q64.V' } else { 'W25Q128.V' }

Write-Output "Programmer name is `"$adapter`"."
if ($env:TB2_FAKE_MODE -ne 'clock-missing') {
    Write-Output "Requested to set SPI clock frequency to $requestedHz Hz. It was actually set to $actualHz Hz"
}
Write-Output "Found Winbond flash chip `"$chip`" (16384 kB, SPI) on serprog."

$readIndex = [array]::IndexOf($args, '-r')
if ($readIndex -ge 0) {
    $readPath = $args[$readIndex + 1]
    $stream = [System.IO.File]::OpenWrite($readPath)
    try {
        if ($env:TB2_FAKE_MODE -eq 'short-read') { $stream.SetLength(128) } else { $stream.SetLength(16MB) }
        if ($env:TB2_FAKE_MODE -eq 'different-read' -and $number -eq 4) {
            $stream.Position = 0
            $stream.WriteByte(42)
        }
    } finally { $stream.Dispose() }
}
exit 0
'@ | Set-Content -LiteralPath $fake -Encoding UTF8

$global:KeyPressCount = 0
$global:RejectKeyAt = 0
$testContinueKey = {
    $global:KeyPressCount++
    if ($global:KeyPressCount -eq $global:RejectKeyAt) { throw 'Test keypress cancelled.' }
    return 'x'
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Label)
    if ($Expected -ne $Actual) { throw "$Label`: expected '$Expected', got '$Actual'." }
}

function Invoke-Scenario {
    <# Execute one isolated session and assert its stop point and retained artifacts. #>
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Mode,
        [int]$RejectAt = 0,
        [Parameter(Mandatory = $true)][int]$Calls,
        [Parameter(Mandatory = $true)][bool]$Succeeds,
        [string]$ErrorPattern = '',
        [string]$ReferenceDump = '',
        [string]$Speed = '500k'
    )

    $scenarioRoot = Join-Path $testRoot $Name
    New-Item -ItemType Directory -Path $scenarioRoot | Out-Null
    $env:TB2_FAKE_MODE = $Mode
    $env:TB2_FAKE_COUNTER = Join-Path $scenarioRoot 'calls.txt'
    $global:KeyPressCount = 0
    $global:RejectKeyAt = $RejectAt
    $failed = $false
    $failureMessage = ''
    try {
        $parameters = @{ Port = 'COM17'; SpiSpeed = $Speed; OutputRoot = $scenarioRoot; FlashromPath = $fake; ContinueKey = $testContinueKey }
        if ($ReferenceDump) { $parameters.ReferenceDump = $ReferenceDump }
        $null = & $runner @parameters 6>&1
    } catch {
        $failed = $true
        $failureMessage = $_.Exception.Message
    }

    if ($Succeeds -eq $failed) { throw "$Name unexpected result: $failureMessage" }
    if ($failed -and $ErrorPattern -and $failureMessage -notmatch $ErrorPattern) {
        throw "$Name failed for the wrong reason: $failureMessage"
    }
    $actualCalls = if (Test-Path -LiteralPath $env:TB2_FAKE_COUNTER) { [int](Get-Content -LiteralPath $env:TB2_FAKE_COUNTER -Raw) } else { 0 }
    Assert-Equal -Expected $Calls -Actual $actualCalls -Label "$Name flashrom calls"
    if ($RejectAt) {
        Assert-Equal -Expected $RejectAt -Actual $global:KeyPressCount -Label "$Name keypress gates"
    }
    $session = @(Get-ChildItem -LiteralPath $scenarioRoot -Directory)
    Assert-Equal -Expected 1 -Actual $session.Count -Label "$Name session count"
    $logs = @(Get-ChildItem -LiteralPath $session[0].FullName -Filter '*.log')
    Assert-Equal -Expected $Calls -Actual $logs.Count -Label "$Name retained logs"
    if ($Succeeds) {
        Assert-Equal -Expected 4 -Actual $global:KeyPressCount -Label "$Name keypress gates"
        Assert-Equal -Expected 3 -Actual @(Get-ChildItem -LiteralPath $session[0].FullName -Filter 'read-*.bin').Count -Label "$Name retained reads"
        if (-not (Test-Path -LiteralPath (Join-Path $session[0].FullName 'SHA256SUMS.txt'))) {
            throw "$Name has no checksum manifest."
        }
    }
    Write-Host "PASS $Name"
    return $session[0].FullName
}

try {
    $null = Invoke-Scenario -Name 'reset-before-probe' -Mode 'normal' -RejectAt 1 -Calls 0 -Succeeds $false -ErrorPattern 'No keypress before chip detection'
    $partial = Invoke-Scenario -Name 'reset-before-second-read' -Mode 'normal' -RejectAt 3 -Calls 2 -Succeeds $false -ErrorPattern 'No keypress before read 2'
    if (-not (Test-Path -LiteralPath (Join-Path $partial 'read-1.bin'))) {
        throw 'The first read was lost after a later reset cancellation.'
    }
    $null = Invoke-Scenario -Name 'clock-high' -Mode 'clock-high' -Calls 1 -Succeeds $false -ErrorPattern 'SPI clock check failed'
    $null = Invoke-Scenario -Name 'clock-missing' -Mode 'clock-missing' -Calls 1 -Succeeds $false -ErrorPattern 'did not report the actual SPI clock'
    $null = Invoke-Scenario -Name 'wrong-adapter' -Mode 'wrong-adapter' -Calls 1 -Succeeds $false -ErrorPattern 'did not confirm programmer name'
    $null = Invoke-Scenario -Name 'wrong-chip' -Mode 'wrong-chip' -Calls 1 -Succeeds $false -ErrorPattern 'did not detect the expected chip'
    $null = Invoke-Scenario -Name 'short-read' -Mode 'short-read' -Calls 2 -Succeeds $false -ErrorPattern 'has 128 bytes'
    $null = Invoke-Scenario -Name 'different-read' -Mode 'different-read' -Calls 4 -Succeeds $false -ErrorPattern 'SHA-256 hashes differ'
    $baseSession = Invoke-Scenario -Name 'success-500k' -Mode 'normal' -Calls 4 -Succeeds $true
    $null = Invoke-Scenario -Name 'success-250k' -Mode 'normal' -Calls 4 -Succeeds $true -Speed '250k'

    $knownGood = Join-Path $testRoot 'known-good.bin'
    Copy-Item -LiteralPath (Join-Path $baseSession 'read-1.bin') -Destination $knownGood
    $null = Invoke-Scenario -Name 'matching-reference' -Mode 'normal' -Calls 4 -Succeeds $true -ReferenceDump $knownGood
    $differentReference = Join-Path $testRoot 'different-reference.bin'
    Copy-Item -LiteralPath $knownGood -Destination $differentReference
    $stream = [System.IO.File]::OpenWrite($differentReference)
    try { $stream.WriteByte(42) } finally { $stream.Dispose() }
    $null = Invoke-Scenario -Name 'different-reference' -Mode 'normal' -Calls 4 -Succeeds $false -ReferenceDump $differentReference -ErrorPattern 'differ from the known-good reference'

    $tooShortReference = Join-Path $testRoot 'short-reference.bin'
    [System.IO.File]::WriteAllBytes($tooShortReference, [byte[]](1, 2, 3))
    $preflightOutput = Join-Path $testRoot 'short-reference-output'
    $env:TB2_FAKE_COUNTER = Join-Path $testRoot 'short-reference-calls.txt'
    $rejectedReference = $false
    try {
        $null = & $runner -Port COM17 -OutputRoot $preflightOutput -ReferenceDump $tooShortReference -FlashromPath $fake -ContinueKey $testContinueKey 6>&1
    } catch {
        $rejectedReference = $_.Exception.Message -match 'ReferenceDump must be exactly'
    }
    Assert-Equal -Expected $true -Actual $rejectedReference -Label 'short reference preflight rejection'
    if (Test-Path -LiteralPath $preflightOutput) { throw 'Short reference created an output directory.' }
    if (Test-Path -LiteralPath $env:TB2_FAKE_COUNTER) { throw 'Short reference started fake flashrom.' }
    Write-Host 'PASS short reference preflight'

    # Load exactly the production byte-comparison function to exercise mismatched bytes.
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($runner, [ref]$null, [ref]$parseErrors)
    if ($parseErrors) { throw 'The runner has a PowerShell parse error.' }
    $functionAst = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Test-ByteIdentical' }, $true)
    if (-not $functionAst) { throw 'The byte-comparison function was not found.' }
    . ([scriptblock]::Create($functionAst.Extent.Text))
    $left = Join-Path $testRoot 'left.bin'
    $right = Join-Path $testRoot 'right.bin'
    [System.IO.File]::WriteAllBytes($left, [byte[]](1, 2, 3))
    [System.IO.File]::WriteAllBytes($right, [byte[]](1, 2, 3))
    Assert-Equal -Expected $true -Actual (Test-ByteIdentical -Left $left -Right $right) -Label 'equal bytes'
    [System.IO.File]::WriteAllBytes($right, [byte[]](1, 2, 4))
    Assert-Equal -Expected $false -Actual (Test-ByteIdentical -Left $left -Right $right) -Label 'different bytes'
    Write-Output 'PASS byte comparison'

    $env:TB2_FAKE_COUNTER = Join-Path $testRoot 'repo-calls.txt'
    $global:KeyPressCount = 0
    $rejectedCheckout = $false
    try {
        $null = & $runner -Port COM17 -OutputRoot (Join-Path (Split-Path $runner -Parent) 'would-be-public-dump') -FlashromPath $fake -ContinueKey $testContinueKey 6>&1
    } catch { $rejectedCheckout = $true }
    Assert-Equal -Expected $true -Actual $rejectedCheckout -Label 'Git checkout output rejection'
    Assert-Equal -Expected 0 -Actual $global:KeyPressCount -Label 'no keypress for checkout output'
    Write-Output 'PASS private output guard'
    Write-Output 'PASS all 12 fake-flashrom scenarios'
} finally {
    Remove-Item Env:\TB2_FAKE_MODE -ErrorAction SilentlyContinue
    Remove-Item Env:\TB2_FAKE_COUNTER -ErrorAction SilentlyContinue
    $resolvedTemp = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\')
    $resolvedTest = [System.IO.Path]::GetFullPath($testRoot)
    if (-not $resolvedTest.StartsWith($resolvedTemp + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove unexpected test path: $resolvedTest"
    }
    Remove-Item -LiteralPath $resolvedTest -Recurse -Force
}
