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
 
# Function to check if Duo is installed
function Is-DuoInstalled {
    $duoInstalled = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |
        Where-Object { $_.DisplayName -like "Duo Authentication for Windows Logon*" }
 
    if (-not $duoInstalled) {
        $duoInstalled = Get-ItemProperty HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* |
            Where-Object { $_.DisplayName -like "Duo Authentication for Windows Logon*" }
    }
 
    return $duoInstalled -ne $null
}
 
 
#run the below on Server 2016 to enable TLS1.2
$osVersion = (Get-WmiObject -Class Win32_OperatingSystem).Version
if ($osVersion -like "10.0*") {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}
 
 
# Main logic
if (Is-DuoInstalled) {
    Write-Host "Duo Authentication for Windows Logon is installed. Proceeding with update..."
 
    # Define download URL and local path
    $duoInstallerUrl = "https://dl.duosecurity.com/duo-win-login-latest.exe"
    $installerPath = "$env:TEMP\duo-win-login-latest.exe"
 
    # Download the latest installer
    Invoke-WebRequest -Uri $duoInstallerUrl -OutFile $installerPath
 
    # Run the installer silently
    Start-Process -FilePath $installerPath -ArgumentList '/S', '/V" /qn REBOOT=ReallySuppress"' -Wait
 
    # Optional: Clean up installer
    Remove-Item $installerPath -Force
 
    Write-Host "Duo update completed."
} else {
    Write-Host "Duo Authentication for Windows Logon is not installed. Skipping update."
}