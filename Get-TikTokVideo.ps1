# Script: Get-TikTokVideo.ps1
# Author: Joe Zollo (@zollo)
#
# A Simple PowerShell Script to parse TikTok's user_data.json file and automate the download of
# raw video files leveraging async HTTP retreival.
#
# Note: Requires the ThreadJob PSMOdule, install with `Install-Module ThreadJob`
# Usage: .\Get-TikTokVideo -JsonFile "C:\Data\user_data.json" -OutputFolder "C:\Data\TikTokVideo"

param (
    [string]$JsonFile = "$($(Get-Location).Path)\user_data.json",
    [string]$OutputFolder = "$($(Get-Location).Path)\TikTok",
    [boolean]$Force = $false
)

if(-not (Get-Module ThreadJob)) {
    Install-Module -Name ThreadJob -Scope CurrentUser
}

# check for valid json file
if(-not (Test-Path $JsonFile)) {
    Write-Error "[ERROR] The provided user data path ($JsonFile) does not exist!"
} else {
    Write-Output "[INFO] Found user data JSON file at $JsonFile"
}

# check for valid output folder, create if needed
if(-not (Test-Path $OutputFolder)) {
    New-Item -ItemType "directory" -Path $OutputFolder -Force
    Write-Output "[INFO] Successfully created folder $OutputFolder"
}

# read json
$json = [PSCustomObject](Get-Content $JsonFile | Out-String | ConvertFrom-Json)
Write-Output "[INFO] Successfully parsed & loaded user data at $JsonFile"

$jobs = @()
$error_count = 0
$total = $json.Video.Videos.VideoList.Length

Write-Output "[INFO] The JSON file contains: $total Video(s)"
Write-Output "[INFO] Writing Videos to $OutputFolder"
Write-Output "[INFO] Starting TikTok Video download, this may take a while!"

# loop over videos and download
$json.Video.Videos.VideoList | ForEach-Object {
    # generate http url
    $uri = $_.Link
    # generate unique file name by removing invalid characters
    $filename = $_.Date.replace(" ", "-").replace(":","-") + ".mp4"
    $full_path = "$OutputFolder\$filename"
    # parse date field
    $date = [datetime]::ParseExact($_.Date, "yyyy-MM-dd HH:mm:ss", $null)
    # check if file already exists
    if(-not (Test-Path $full_path) -or $Force) {
        # generate thread job
        $jobs += Start-ThreadJob -StreamingHost $Host -Name $filename -ScriptBlock {
            $Uri = $using:uri
            $OutFile = "$using:OutputFolder\$using:filename"
            try {
                $resp = Invoke-WebRequest -TimeoutSec 30 -Uri $Uri -OutFile $OutFile
                (Get-ChildItem $OutFile).CreationTime = $using:date
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

foreach ($j in $jobs) {
    $total_jobs = [int]$(Get-Job).Length
    $completed_jobs = [int]$(Get-Job -State Completed).Length
    $pct = ($completed_jobs/$total_jobs * 100)
    Receive-Job -Job $j -Wait -AutoRemoveJob
}

# cleanup jobs
Get-Job | Remove-Job -Force