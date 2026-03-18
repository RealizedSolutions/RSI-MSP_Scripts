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
 
# Check if running as System
$sid = ([System.Security.Principal.WindowsIdentity]::GetCurrent()).User.Value
if ($sid -ne "S-1-5-18") {
    Write-Host "This script needs to be run as System."
    Exit 1
}
$c2rPaths =@(
    "$($env:ProgramFiles)\Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe"
    "${env:ProgramFiles(x86)}\Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe"
)
# Add a flag to indicate whether the update was performed or not
$updatePerformed = $false
# Check each path to see which is correct
foreach ($c2rPath in $c2rPaths) {
    $pathExists = Test-Path -Path $c2rPath -PathType Leaf
    if ($pathExists) {
        Write-Host "Updating Office using C2R located at '$($c2rPath)'."
        try {           
            $result = Start-Process -FilePath $c2rPath -ArgumentList "/update user displaylevel=false updatepromptuser=false forceappshutdown=true" -PassThru -Wait
        } catch {
            Write-Host "An error occurred updating Office."
            Exit 1
        }
        if ($result.ExitCode -eq 0) {
            Write-Host "Successfully called the Office C2R updater."
            $updatePerformed = $true # Set the flag to true when the update is successful
        } else {
            Write-Host "The Office C2R updater was not called successfully. Please investigate."
            # Put code here to create an alert
            Exit 1
        }
    }
}