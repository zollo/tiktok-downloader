# Script: Get-TikTokVideo.ps1
# Author: Joe Zollo (@zollo)
#
# A Simple PowerShell Script to parse TikTok's user_data.json file and automate the download of
# raw video files leveraging async HTTP retreival.
#
# Note: Requires the ThreadJob PSMOdule, install with `Install-Module ThreadJob`
# EXAMPLE USAGE: .\Get-TikTokVideo -JsonFile "C:\Data\user_data.json" -OutputFolder "C:\Data\TikTokVideo"

#Requires -Modules ThreadJob

param (
    [string]$JsonFile = "$($(get-location).Path)\user_data.json",
    [string]$OutputFolder = "$($(get-location).Path)\TikTok",
    [boolean]$Force = $false
)

# check for valid json file
if(-not (Test-Path $JsonFile)) {
    Write-Error "[ERROR] The provided user data path ($JsonFile) does not exist!"
} else {
    Write-Output "[INFO] Found user data JSON file at $JsonFile"
}

# check for valid output folder, create if needed
if(-not (Test-Path $OutputFolder)) {
    New-Item -ItemType "directory" -Path "$($(get-location).Path)\TikTok" -Force
}

# read json
$json = [PSCustomObject](Get-Content $JsonFile | Out-String | ConvertFrom-Json)
Write-Output "[INFO] Successfully parsed & loaded user data at $JsonFile"

$jobs = @()

# loop over videos and download
$json.Video.Videos.VideoList | ForEach-Object {
    # generate http url
    $uri = $_.Link
    # generate unique file name by removing invalid characters
    $filename = $_.Date.replace(" ", "-").replace(":","-") + ".mp4"
    # check if file already exists
    if(-not (Test-Path $filename) -or $Force) {
        # generate thread job
        $jobs += Start-ThreadJob -Name $filename -ScriptBlock {
            $Uri = $using:uri
            $OutFile = "$using:OutputFolder\$using:filename"
            try {
                $resp = Invoke-WebRequest -Uri $Uri -OutFile $OutFile
                Write-Output "[INFO] Wrote file to $OutFile"
            } catch {
                $status = $_.Exception.Response.StatusCode.value__
                Write-Error "[ERROR] Failed to download $using:filename - HTTP Error $status"
            }
        }
    } else {
        Write-Output "[INFO] $filename already downloaded, skipping!"
    }
}

Write-Host "[INFO] Starting TikTok Video download, this may take a while!"
Wait-Job -Job $jobs

foreach ($j in $jobs) {
    Receive-Job -Job $j
}