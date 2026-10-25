# First target-flash dump — C3 Shield

This is a read-only acceptance sequence for an assembled Shield and a 16 MiB W25Q128 flash. Use the ESP32-C3 serprog firmware with **PowerShell and flashrom**. The firmware may be installed and its serial port visible, but the Shield-to-target connection remains an **unverified build candidate** until the physical checks and reads succeed. Keep target dumps outside this public repository.

## 1. Inspect with power off

1. Disconnect the target's battery and USB. Disconnect the ESP32-C3 USB cable. Fit the module with its USB connector pointing toward the Shield's USB arrow; check J1's notch, pin 1 and the clip's actual pin-to-pin continuity.
2. Measure all eight paths from the module through J1 to the SOP8 contacts against the [pin table](hardware.md#j1-and-sop8-mapping). Check for unintended adjacent-pin, 3.3 V-to-GND and SPI-to-supply shorts.
3. Leave JP1 open. Verify that its input and output have no direct short and that R1 is the 10 kΩ /CS pull-up. Check the target chip is a compatible 3.3 V part. Do not attach the clip if its pinout or orientation is uncertain.

## 2. Prove the supply and reset

1. With the target still disconnected, power the ESP32-C3 by USB. Check 3.3 V at JP1's input. With JP1 open, check the J1 VCC side; with JP1 closed, check approximately 3.3 V and correct polarity at J1 VCC, /WP and /HOLD. Stop if the voltage or polarity is wrong.
2. Reopen JP1 and connect the clip while transfers are stopped. Check the target-chip VCC and GND. Then close JP1 and measure approximately 3.3 V at the chip under load.
3. **A reset is proven only if chip VCC actually falls low enough when power is removed.** JP1 interrupts only the direct supply; SPI pins may backfeed the chip. If VCC does not fall, stop and resolve this before claiming a reset. Disconnect USB before changing the clip or wiring; reconnect and repeat the electrical checks afterward.

## 3. Detect and take three independent reads

Open PowerShell in a private directory outside any Git checkout with flashrom available on `PATH`. Replace `COM17` with the port identified immediately before the session. The `115200` part is the serprog serial-port setting; `spispeed=500k` requests a **500 kHz SPI clock**. flashrom can warn yet continue if the programmer rejects a speed change, so the example checks its verbose report of the [actual clock](https://github.com/flashrom/flashrom/blob/main/programmers/serprog.c). Keep the target battery and target USB disconnected.

```powershell
$programmer = 'serprog:dev=COM17:115200,spispeed=500k'
$chip = 'W25Q128.V'
```

Before **each** flashrom call below, the function pauses. Open JP1, verify that flash VCC falls, close JP1, verify approximately 3.3 V at the flash, then type `RESET`. Any other response stops the sequence. Leave the ESP32-C3 USB connection in place while power-cycling only the target.

```powershell
function Invoke-AfterTargetReset {
    param([string[]]$FlashromArguments)

    $reply = Read-Host 'Power-cycle the flash with JP1, measure VCC, then type RESET'
    if ($reply -cne 'RESET') { throw 'Target reset not confirmed; flashrom was not started.' }
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& flashrom -V @FlashromArguments 2>&1)
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    $output | ForEach-Object { Write-Host $_ }
    if ($exitCode -ne 0) { throw "flashrom failed with exit code $exitCode" }
    $report = $output -join "`n"
    $frequency = [regex]::Match($report, 'Requested to set SPI clock frequency to 500000 Hz\. It was actually set to (\d+) Hz')
    if (-not $frequency.Success -or [int]$frequency.Groups[1].Value -le 0 -or
        [int]$frequency.Groups[1].Value -gt 500000) {
        throw 'The requested 500 kHz SPI clock was not confirmed; stop.'
    }
    $readIndex = [Array]::IndexOf($FlashromArguments, '-r')
    if ($readIndex -ge 0 -and (Get-Item -LiteralPath $FlashromArguments[$readIndex + 1]).Length -ne 16MB) {
        throw 'Unexpected read size; expected exactly 16,777,216 bytes.'
    }
}

Invoke-AfterTargetReset -FlashromArguments @('-p', $programmer, '-c', $chip)
Invoke-AfterTargetReset -FlashromArguments @('-p', $programmer, '-c', $chip, '-r', '.\read-1.bin')
Invoke-AfterTargetReset -FlashromArguments @('-p', $programmer, '-c', $chip, '-r', '.\read-2.bin')
Invoke-AfterTargetReset -FlashromArguments @('-p', $programmer, '-c', $chip, '-r', '.\read-3.bin')
```

After detection, require the expected 16 MiB Winbond chip. After each read, stop on any flashrom error or unexpected size. Each read must contain exactly **16,777,216 bytes**. Compare all three SHA-256 hashes and also compare the files byte for byte:

```powershell
$reads = 'read-1.bin', 'read-2.bin', 'read-3.bin'
$reads | ForEach-Object {
    $file = Get-Item -LiteralPath $_
    [pscustomobject]@{
        File = $file.Name
        Bytes = $file.Length
        SHA256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    }
}
fc.exe /b .\read-1.bin .\read-2.bin
if ($LASTEXITCODE -ne 0) { throw 'Read 1 and read 2 differ.' }
fc.exe /b .\read-1.bin .\read-3.bin
if ($LASTEXITCODE -ne 0) { throw 'Read 1 and read 3 differ.' }
```

All sizes and hashes must agree, and both `fc.exe` comparisons must report no differences. Compare with a known-good dump of the **same unchanged flash**, if available. Matching reads prove repeatability of this connection, not that the contents are independently correct. Preserve the original backup privately.

If detection, voltage or repeated reads fail, stop and inspect the physical connection. Consider **250 kHz** only after checking wiring and power. Do not write or erase during first acceptance. A future flash operation requires its own reset pause immediately before writing, renewed chip detection and a separate verified backup.
