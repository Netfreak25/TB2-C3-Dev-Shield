# Read-only, reset-gated acceptance dump for the TB2 C3 Dev Shield.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^COM[1-9][0-9]*$')]
    [string]$Port,

    [ValidateSet('500k', '250k')]
    [string]$SpiSpeed = '500k',

    [string]$OutputRoot = (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'TB2-C3-Dumps'),

    [string]$ReferenceDump,

    [string]$FlashromPath = 'flashrom',

    [switch]$ManualReset,

    [ValidateRange(1, 3600)]
    [int]$ResetTimeoutSeconds = 180,

    [Parameter(DontShow = $true)]
    [scriptblock]$ContinueKey = {
        $Host.UI.RawUI.FlushInputBuffer()
        $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$expectedBytes = 16MB
$chipName = 'W25Q128.V'
$programmerName = 'tb2-c3-serprog'
$requestedHz = if ($SpiSpeed -eq '250k') { 250000 } else { 500000 }
$programmer = "serprog:dev=${Port}:115200,spispeed=$SpiSpeed"
$resetPollMilliseconds = 200

function Assert-PrivatePath {
    <# Keep both output and reference images outside Git checkouts and links. #>
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Purpose
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $cursor = $fullPath
    while ($cursor) {
        if (Test-Path -LiteralPath (Join-Path $cursor '.git')) {
            throw "$Purpose is inside a Git checkout: $fullPath"
        }
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -LiteralPath $cursor -Force
            if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "$Purpose traverses a linked directory: $cursor"
            }
        }
        $parent = [System.IO.Path]::GetDirectoryName($cursor)
        if (-not $parent -or $parent -eq $cursor) { break }
        $cursor = $parent
    }
    return $fullPath
}

function Get-PortSnapshot {
    <# Observe Windows PnP without opening the serial port. #>
    param(
        [Parameter(Mandatory = $true)][string]$PortName,
        [string]$ExpectedInstanceId
    )

    $portSuffix = '\(' + [regex]::Escape($PortName) + '\)$'
    try {
        if ($ExpectedInstanceId) {
            $devices = @(Get-PnpDevice -InstanceId $ExpectedInstanceId -PresentOnly -ErrorAction Stop)
        } else {
            $devices = @(Get-PnpDevice -Class Ports -PresentOnly -ErrorAction Stop |
                Where-Object { $_.FriendlyName -match $portSuffix })
        }
    } catch {
        if ($ExpectedInstanceId -and $_.FullyQualifiedErrorId -like 'CmdletizationQuery_NotFound*') {
            return $null
        }
        throw "Cannot inspect Windows PnP port $PortName`: $($_.Exception.Message)"
    }
    if ($devices.Count -eq 0) { return $null }
    if ($devices.Count -ne 1) { throw "More than one device matches $PortName; automatic reset detection is unsafe." }

    $device = $devices[0]
    if ($device.Status -ne 'OK') { return $null }
    if ($device.FriendlyName -notmatch $portSuffix) {
        throw "$PortName is no longer assigned to the selected USB device. Restart with the current port."
    }
    $instanceId = [string]$device.InstanceId
    if ($instanceId -notlike 'USB\*') {
        throw "$PortName is not a USB serial device; use -ManualReset."
    }
    if ($ExpectedInstanceId -and $instanceId -ine $ExpectedInstanceId) {
        throw "$PortName now belongs to another USB device; restart with the current port."
    }

    try {
        $arrival = Get-PnpDeviceProperty -InstanceId $instanceId -KeyName 'DEVPKEY_Device_LastArrivalDate' -ErrorAction Stop
    } catch {
        if ($ExpectedInstanceId -and $_.FullyQualifiedErrorId -like 'CmdletizationQuery_NotFound*') {
            return $null
        }
        throw "Cannot read $PortName arrival time: $($_.Exception.Message)"
    }
    if ($arrival.Data -isnot [datetime]) {
        throw "$PortName has no usable last-arrival timestamp; use -ManualReset."
    }
    return [pscustomobject]@{ InstanceId = $instanceId; LastArrival = [datetime]$arrival.Data }
}

function Wait-ForTargetReset {
    <# USB re-enumeration is only a continuation signal, not proof of target VCC reset. #>
    param(
        [Parameter(Mandatory = $true)][string]$Operation,
        [string]$PortInstanceId
    )

    if ($ManualReset) {
        Write-Host "Before $Operation`: keep target battery/USB disconnected. Open JP1 and verify flash VCC falls, then close JP1 and verify about 3.3 V at the chip."
        Write-Host 'After measuring both voltages, press any key to continue (Ctrl+C aborts).'
        try {
            $null = & $ContinueKey
        } catch {
            throw "No keypress before $Operation; flashrom was not started. An interactive console is required. $($_.Exception.Message)"
        }
        return
    }

    $clock = [System.Diagnostics.Stopwatch]::StartNew()
    $previousArrival = $null
    $baseline = $null
    Write-Host "Waiting for $Port to be present and stable before $Operation..."
    while ($clock.Elapsed.TotalSeconds -lt $ResetTimeoutSeconds) {
        $candidate = Get-PortSnapshot -PortName $Port -ExpectedInstanceId $PortInstanceId
        if ($candidate) {
            if ($previousArrival -and $candidate.LastArrival -eq $previousArrival) {
                $baseline = $candidate
                break
            }
            $previousArrival = $candidate.LastArrival
        } else {
            $previousArrival = $null
        }
        Start-Sleep -Milliseconds $resetPollMilliseconds
    }
    if (-not $baseline) {
        throw "$Port did not become stable before $Operation; flashrom was not started."
    }

    $clock.Restart()
    Write-Host "Before $Operation`: keep target battery/USB disconnected. The JP1 off/on voltage check must already be complete; automatic mode continues immediately after USB re-enumeration."
    Write-Host "Open JP1, then close it. Waiting for the selected USB device on $Port to reconnect (Ctrl+C aborts). This does not prove that target VCC fell."
    while ($clock.Elapsed.TotalSeconds -lt $ResetTimeoutSeconds) {
        $current = Get-PortSnapshot -PortName $Port -ExpectedInstanceId $PortInstanceId
        if ($current -and $current.LastArrival -gt $baseline.LastArrival) {
            Write-Host "$Port reappeared; continuing with $Operation."
            return
        }
        Start-Sleep -Milliseconds $resetPollMilliseconds
    }
    throw "Timed out waiting for a new $Port USB arrival before $Operation; flashrom was not started. Use -ManualReset if JP1 does not reconnect USB."
}

function Assert-FlashromReport {
    <# Require the expected adapter, flash chip, and confirmed SPI clock. #>
    param(
        [Parameter(Mandatory = $true)][string]$Report,
        [Parameter(Mandatory = $true)][int]$ClockHz,
        [Parameter(Mandatory = $true)][string]$Adapter,
        [Parameter(Mandatory = $true)][string]$Chip
    )

    if ($Report -cnotmatch ('Programmer name is "' + [regex]::Escape($Adapter) + '"')) {
        throw "flashrom did not confirm programmer name $Adapter."
    }
    if ($Report -cnotmatch ('Found[^\r\n]*flash chip "' + [regex]::Escape($Chip) + '"')) {
        throw "flashrom did not detect the expected chip $Chip."
    }

    $clockReports = [regex]::Matches(
        $Report,
        'Requested to set SPI clock frequency to\s+(\d+)\s+Hz\.\s+It was actually set to\s+(\d+)\s+Hz'
    )
    if ($clockReports.Count -eq 0) {
        throw 'flashrom did not report the actual SPI clock.'
    }
    $lastClockReport = $clockReports[$clockReports.Count - 1]
    $reportedRequest = [int64]$lastClockReport.Groups[1].Value
    $actualHz = [int64]$lastClockReport.Groups[2].Value
    if ($reportedRequest -ne $ClockHz -or $actualHz -le 0 -or $actualHz -gt $ClockHz) {
        throw "SPI clock check failed: requested $ClockHz Hz, flashrom reported $reportedRequest Hz requested and $actualHz Hz actual."
    }
}

function Invoke-FlashromStep {
    <# Stream the native process output to the console and a persistent session log. #>
    param(
        [Parameter(Mandatory = $true)][string]$Operation,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$LogPath,
        [string]$PortInstanceId
    )

    Wait-ForTargetReset -Operation $Operation -PortInstanceId $PortInstanceId
    $lines = New-Object 'System.Collections.Generic.List[string]'
    $oldPreference = $ErrorActionPreference
    try {
        # Native stderr is diagnostic output in Windows PowerShell 5.1.
        $ErrorActionPreference = 'Continue'
        $global:LASTEXITCODE = 0
        & $FlashromPath -V @Arguments 2>&1 | ForEach-Object {
            $line = [string]$_
            $lines.Add($line)
            Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
            Write-Host $line
        }
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $oldPreference
    }

    if ($exitCode -ne 0) {
        throw "flashrom failed during $Operation with exit code $exitCode. See $LogPath"
    }
    Assert-FlashromReport -Report ($lines -join "`n") -ClockHz $requestedHz -Adapter $programmerName -Chip $chipName
}

function Test-ByteIdentical {
    <# Compare every byte with bounded memory, independently of SHA-256. #>
    param(
        [Parameter(Mandatory = $true)][string]$Left,
        [Parameter(Mandatory = $true)][string]$Right
    )

    $leftFile = [System.IO.File]::OpenRead($Left)
    $rightFile = [System.IO.File]::OpenRead($Right)
    try {
        if ($leftFile.Length -ne $rightFile.Length) { return $false }
        $leftBuffer = New-Object byte[] 65536
        $rightBuffer = New-Object byte[] 65536
        while ($leftFile.Position -lt $leftFile.Length) {
            $blockSize = [int][Math]::Min($leftBuffer.Length, $leftFile.Length - $leftFile.Position)
            foreach ($pair in @(@($leftFile, $leftBuffer), @($rightFile, $rightBuffer))) {
                $stream = $pair[0]
                $buffer = $pair[1]
                $filled = 0
                while ($filled -lt $blockSize) {
                    $count = $stream.Read($buffer, $filled, $blockSize - $filled)
                    if ($count -le 0) { return $false }
                    $filled += $count
                }
            }
            # Bytes outside a partial final block were equal in the preceding block.
            if (-not [System.Collections.StructuralComparisons]::StructuralEqualityComparer.Equals($leftBuffer, $rightBuffer)) {
                return $false
            }
        }
        return ($rightFile.Position -eq $rightFile.Length)
    } finally {
        $leftFile.Dispose()
        $rightFile.Dispose()
    }
}

function Invoke-FirstDump {
    <# Probe, read three complete images, and require identical hashes and bytes. #>
    $resolvedFlashrom = Get-Command -Name $FlashromPath -ErrorAction Stop
    $privateRoot = Assert-PrivatePath -Path $OutputRoot -Purpose 'OutputRoot'
    $portBinding = $null
    if (-not $ManualReset) {
        $portBinding = Get-PortSnapshot -PortName $Port
        if (-not $portBinding) { throw "$Port is not present; automatic reset detection cannot start." }
    }
    $portInstanceId = if ($portBinding) { $portBinding.InstanceId } else { $null }
    $referencePath = $null
    if ($ReferenceDump) {
        $referencePath = Assert-PrivatePath -Path $ReferenceDump -Purpose 'ReferenceDump'
        if (-not (Test-Path -LiteralPath $referencePath -PathType Leaf)) {
            throw 'ReferenceDump is not an existing file.'
        }
        if ((Get-Item -LiteralPath $referencePath).Length -ne $expectedBytes) {
            throw "ReferenceDump must be exactly $expectedBytes bytes."
        }
    }
    $sessionName = '{0}-{1}' -f (Get-Date -Format 'yyyyMMdd-HHmmss'), ([guid]::NewGuid().ToString('N').Substring(0, 8))
    $sessionPath = Join-Path $privateRoot $sessionName
    New-Item -ItemType Directory -Path $sessionPath -ErrorAction Stop | Out-Null
    Write-Host "Private session: $sessionPath"
    Write-Host "flashrom: $($resolvedFlashrom.Source); port: $Port; requested SPI clock: $SpiSpeed"

    $baseArguments = @('-p', $programmer, '-c', $chipName)
    Invoke-FlashromStep -Operation 'chip detection' -Arguments $baseArguments -LogPath (Join-Path $sessionPath 'probe.log') -PortInstanceId $portInstanceId

    $reads = @()
    for ($number = 1; $number -le 3; $number++) {
        $readPath = Join-Path $sessionPath "read-$number.bin"
        $logPath = Join-Path $sessionPath "read-$number.log"
        Invoke-FlashromStep -Operation "read $number" -Arguments ($baseArguments + @('-r', $readPath)) -LogPath $logPath -PortInstanceId $portInstanceId
        if (-not (Test-Path -LiteralPath $readPath)) {
            throw "Read $number created no image. See $logPath"
        }
        $actualBytes = (Get-Item -LiteralPath $readPath).Length
        if ($actualBytes -ne $expectedBytes) {
            throw "Read $number has $actualBytes bytes; expected $expectedBytes. Image and log were kept in $sessionPath"
        }
        $reads += $readPath
    }

    $hashes = @($reads | ForEach-Object { (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash.ToLowerInvariant() })
    if (@($hashes | Select-Object -Unique).Count -ne 1) {
        throw "The three SHA-256 hashes differ. Images and logs were kept in $sessionPath"
    }
    if (-not (Test-ByteIdentical -Left $reads[0] -Right $reads[1]) -or
        -not (Test-ByteIdentical -Left $reads[0] -Right $reads[2])) {
        throw "The three images differ byte for byte. Images and logs were kept in $sessionPath"
    }
    if ($referencePath) {
        $referenceHash = (Get-FileHash -LiteralPath $referencePath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($referenceHash -ne $hashes[0] -or -not (Test-ByteIdentical -Left $reads[0] -Right $referencePath)) {
            throw "The C3 reads differ from the known-good reference. Images and logs were kept in $sessionPath"
        }
    }

    $sumLines = for ($index = 0; $index -lt $reads.Count; $index++) {
        '{0}  {1}' -f $hashes[$index], [System.IO.Path]::GetFileName($reads[$index])
    }
    Set-Content -LiteralPath (Join-Path $sessionPath 'SHA256SUMS.txt') -Value $sumLines -Encoding ASCII
    Write-Host "Three complete $expectedBytes-byte reads are identical by SHA-256 and byte comparison."
    Write-Host "Keep this private backup: $sessionPath"
}

Invoke-FirstDump
