#
Adobe Acrobat/Reader Cleaner Tool runner
- Scrapes Adobe ETK AcroCleaner page to find the current .exe download link
- Downloads to C:\ProgramData\RealizedSolutions\AdobeCleaner
- Runs silently with supported command-line switches
<installername>.exe /silent /product=<ProductId> /installpath=<InstallPath> /cleanlevel=<CleanLevel> /scanforothers=<ScanForOthers> [1](https://www.adobe.com/devnet-docs/acrobatetk/tools/Labs/cleaner.html?linkId=100000385162360)
#>
 
# MIT License
#
# Copyright (c) 2026 Realized, Solutions, Inc
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
 
 
# -----------------------------
# Config (adjust as needed)
# -----------------------------
$WorkDir     = Join-Path $env:ProgramData "RealizedSolutions\AdobeCleaner"
$CleanerExe  = Join-Path $WorkDir "AcroCleaner.exe"
$LogFile     = Join-Path $WorkDir ("AcroCleaner_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
 
# Adobe’s official ETK page (stable)
$AdobeCleanerInfoPage = "https://www.adobe.com/devnet-docs/acrobatetk/tools/Labs/cleaner.html"
 
# Cleaner options (documented by Adobe)
# ProductId: 0=Acrobat, 1=Reader [1](https://www.adobe.com/devnet-docs/acrobatetk/tools/Labs/cleaner.html?linkId=100000385162360)
$ProductId     = 1
$CleanLevel    = 1   # 0 = selected product only, 1 = include shared components [1](https://www.adobe.com/devnet-docs/acrobatetk/tools/Labs/cleaner.html?linkId=100000385162360)
$ScanForOthers = 1   # 1 = system-wide search [1](https://www.adobe.com/devnet-docs/acrobatetk/tools/Labs/cleaner.html?linkId=100000385162360)
 
# Optional: specify install path only if ScanForOthers = 0 (per Adobe) [1](https://www.adobe.com/devnet-docs/acrobatetk/tools/Labs/cleaner.html?linkId=100000385162360)
$InstallPath = "default"
 
# Backup URLs (optional) - add your internal hosted copy here if you have one
$FallbackUrls = @(
  # Example: "https://your-internal-server/software/AcroCleaner.exe"
)
 
# -----------------------------
# Helpers
# -----------------------------
function Write-Log {
    param([string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$ts  $Message"
    Write-Output $line
    try { Add-Content -Path $LogFile -Value $line -ErrorAction Stop } catch {}
}
 
function Ensure-Tls12 {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    } catch {}
}
 
function Download-File {
    param(
      [Parameter(Mandatory=$true)][string]$Url,
      [Parameter(Mandatory=$true)][string]$Destination
    )
 
    Ensure-Tls12
    Write-Log "Attempting download: $Url"
 
    # Prefer BITS, fall back to Invoke-WebRequest
    try {
        Start-BitsTransfer -Source $Url -Destination $Destination -ErrorAction Stop
        Write-Log "Download completed via BITS."
        return $true
    } catch {
        Write-Log "BITS failed: $($_.Exception.Message). Trying Invoke-WebRequest..."
        try {
            Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing -ErrorAction Stop
            Write-Log "Download completed via Invoke-WebRequest."
            return $true
        } catch {
            Write-Log "Invoke-WebRequest failed: $($_.Exception.Message)"
            return $false
        }
    }
}
 
function Get-CleanerDownloadUrlFromAdobePage {
    param([string]$InfoPageUrl)
 
    Ensure-Tls12
    Write-Log "Fetching Adobe info page to locate cleaner download URL..."
    $resp = Invoke-WebRequest -Uri $InfoPageUrl -UseBasicParsing -ErrorAction Stop
 
    # Find first href ending in .exe (Adobe may change exact filename)
    $exeLink = $null
 
    # Look in parsed links if available
    if ($resp.Links) {
        $exeLink = $resp.Links | Where-Object { $_.href -match '\.exe(\?|$)' } | Select-Object -First 1
        if ($exeLink -and $exeLink.href) {
            $href = $exeLink.href
            if ($href -notmatch '^https?://') {
                $base = [System.Uri]$InfoPageUrl
                $href = (New-Object System.Uri($base, $href)).AbsoluteUri
            }
            return $href
        }
    }
 
    # Fallback: regex scan of raw HTML
    $m = [regex]::Match($resp.Content, '(https?:\/\/[^\s"''>]+\.exe(?:\?[^\s"''>]+)?)', 'IgnoreCase')
    if ($m.Success) { return $m.Groups[1].Value }
 
    return $null
}
 
# -----------------------------
# Start
# -----------------------------
try {
    if (-not (Test-Path $WorkDir)) { New-Item -Path $WorkDir -ItemType Directory -Force | Out-Null }
    "=== Adobe Acrobat Cleaner Tool Run ===" | Out-File -FilePath $LogFile -Encoding UTF8 -Force
 
    Write-Log "WorkDir: $WorkDir"
    Write-Log "Cleaner Path: $CleanerExe"
    Write-Log "Running as: $([Security.Principal.WindowsIdentity]::GetCurrent().Name)"
 
    # Build args (Adobe supported switches) [1](https://www.adobe.com/devnet-docs/acrobatetk/tools/Labs/cleaner.html?linkId=100000385162360)
    if ($ScanForOthers -eq 0 -and $InstallPath -ne "default") {
        $CleanerArgs = "/silent /product=$ProductId /installpath=`"$InstallPath`" /cleanlevel=$CleanLevel /scanforothers=$ScanForOthers"
    } else {
        $CleanerArgs = "/silent /product=$ProductId /installpath=default /cleanlevel=$CleanLevel /scanforothers=$ScanForOthers"
    }
    Write-Log "Args: $CleanerArgs"
 
    # Download if missing/invalid
    $needsDownload = $true
    if (Test-Path $CleanerExe) {
        $fi = Get-Item $CleanerExe -ErrorAction SilentlyContinue
        if ($fi -and $fi.Length -gt 0) { $needsDownload = $false }
    }
 
    if ($needsDownload) {
        Write-Log "Cleaner not present (or invalid). Resolving current download URL from Adobe page..."
        $dl = Get-CleanerDownloadUrlFromAdobePage -InfoPageUrl $AdobeCleanerInfoPage
 
        $downloaded = $false
        if ($dl) {
            Write-Log "Found cleaner download URL: $dl"
            $downloaded = Download-File -Url $dl -Destination $CleanerExe
        } else {
            Write-Log "WARNING: Could not locate .exe link on Adobe page."
        }
 
        # Fallback list (internal mirror, etc.)
        if (-not $downloaded -and $FallbackUrls.Count -gt 0) {
            foreach ($u in $FallbackUrls) {
                if (Download-File -Url $u -Destination $CleanerExe) { $downloaded = $true; break }
            }
        }
 
        if (-not $downloaded) {
            Write-Log "FATAL: Failed to download Acrobat Cleaner Tool from Adobe page and fallbacks."
            exit 2
        }
    } else {
        Write-Log "Cleaner already present; skipping download."
    }
 
    if (-not (Test-Path $CleanerExe)) {
        Write-Log "FATAL: Cleaner executable not found."
        exit 2
    }
 
    # Run cleaner
    Write-Log "Starting Adobe Cleaner..."
    $p = Start-Process -FilePath $CleanerExe -ArgumentList $CleanerArgs -Wait -PassThru -WindowStyle Hidden
    $exitCode = $p.ExitCode
    Write-Log "Cleaner finished. ExitCode: $exitCode"
 
    # Adobe creates its own log in user temp path when run interactively; under SYSTEM it can land under system temp. [1](https://www.adobe.com/devnet-docs/acrobatetk/tools/Labs/cleaner.html?linkId=100000385162360)
    # This script’s log is always in $WorkDir.
 
    exit $exitCode
}
catch {
    Write-Log "FATAL: $($_.Exception.Message)"
    Write-Log $_.ScriptStackTrace
    exit 1
}