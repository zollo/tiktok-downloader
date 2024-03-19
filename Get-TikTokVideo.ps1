# Script: Get-TikTokVideo.ps1
# Author: Joe Zollo (@zollo)
#
# A Simple PowerShell Script to parse TikTok's user_data.json file and automate the download of
# raw video files leveraging async HTTP retreival.
#
# Note: Requires the ThreadJob PSModule, install with `Install-Module ThreadJob`
# Usage: .\Get-TikTokVideo -JsonFile "C:\Data\user_data.json" -OutputFolder "C:\Data\TikTokVideo"

param (
    [string]$JsonFile = "$($(Get-Location).Path)\user_data.json",
    [string]$OutputFolder = "$($(Get-Location).Path)\TikTok",
    [boolean]$Force = $false,
    [boolean]$Verbose = $false
)

if(-not (Get-Module ThreadJob)) {
    Set-PSRepository -Name "PSGallery" -InstallationPolicy Untrusted
    Install-Module -Name ThreadJob -Scope CurrentUser
}

# cleanup errant jobs
Get-Job | Remove-Job -Force

# check for valid json file
if(-not (Test-Path $JsonFile)) {
    Write-Error "[ERROR] The provided user data path ($JsonFile) does not exist!"
} else {
    Write-Host "[INFO] Found user data JSON file at $JsonFile" -ForegroundColor Green
}

# check for valid output folder, create if needed
if(-not (Test-Path $OutputFolder)) {
    New-Item -ItemType "directory" -Path $OutputFolder -Force
    Write-Host "[INFO] Successfully created folder $OutputFolder" -ForegroundColor Green
}

# read json
$json = [PSCustomObject](Get-Content $JsonFile | Out-String | ConvertFrom-Json)
Write-Host "[INFO] Successfully parsed & loaded user data at $JsonFile" -ForegroundColor Green

$jobs = @()

$total_photo = 0
$total_na = 0
$total_video = 0

$json.Video.Videos.VideoList | ForEach-Object {
    $link = $_.Link
    $link_len = $link.split(' ').Length
    if($_.Link -eq 'N/A') {
        $total_na++
    } elseif ($link_len -gt 1) {
        $total_photo++
    } else {
        $total_video++
    }
}

Write-Host "[INFO] Writing Videos to $OutputFolder"
Write-Host "[INFO] Starting TikTok Video download, this may take a while!"

# loop over videos and download
$json.Video.Videos.VideoList | ForEach-Object {
    # generate http url
    $uri = $_.Link

    # generate unique file name by removing invalid characters
    $filename = $_.Date.replace(" ", "-").replace(":","-") + ".mp4"
    $full_path = "$OutputFolder\$filename"

    # parse date field
    $date = [datetime]::ParseExact($_.Date, "yyyy-MM-dd HH:mm:ss", $null)

    if(Test-Path $full_path) {
        # get filesize
        $filedata = Get-Item -LiteralPath $full_path

        # cleanup erroneous files less than 1000 bytes
        if($filedata.Length -lt 1000) {
            Remove-Item -LiteralPath $full_path -Force
        }
    }

    if($uri -eq "N/A") {
        # parse erroneous post
        Write-Host "[INFO][$filename] has no available link, skipping." -ForegroundColor Cyan
    } elseif($uri.split(' ').Length -gt 1) {
        # parse photos post
        Write-Host "[INFO][$filename] is a photos post, skipping." -ForegroundColor DarkMagenta
    } else {
        # check if file already exists
        if(-not (Test-Path $full_path) -or $Force) {
            # generate thread job
            $jobs += Start-ThreadJob -StreamingHost $Host -Name $filename -ScriptBlock {
                $Uri = $using:uri
                $OutFile = "$using:OutputFolder\$using:filename"
                # parse video post
                try {
                    $resp = Invoke-WebRequest -TimeoutSec 30 -Uri $using:uri -OutFile $OutFile
                    # set the creation date from json metadata
                    (Get-ChildItem $OutFile).CreationTime = $using:date
                    Write-Host "[INFO][$using:filename] Wrote file to $OutFile"
                } catch {
                    # save exception data
                    $status = $_.Exception.Response.StatusCode.value__
                    Write-Error "[ERROR][$using:filename] Failed to download - HTTP Error $status"
                    # cleanup partially downloaded file
                    if(Test-Path $using:full_path) {
                        Remove-Item -LiteralPath $using:full_path -Force
                    }
                }
            }
        } else {
            if($Verbose) {
                Write-Host "[INFO][$filename] already downloaded, skipping!" -ForegroundColor DarkCyan
            }
        }
    }
}

# loop over jobs
foreach ($j in $jobs) {
    Receive-Job -Job $j -Wait
}

# cleanup jobs
Get-Job | Remove-Job -Force

# calculate output folder items
$folder_data = Get-ChildItem "$($(Get-Location).Path)\TikTok"
$output_folder_items = $folder_data.Length

Write-Host "[INFO] Total Video: $total_video ($output_folder_items in output folder)" -ForegroundColor DarkYellow
Write-Host "[INFO] Total Photo: $total_photo" -ForegroundColor DarkYellow
Write-Host "[INFO] Total N/A: $total_na" -ForegroundColor DarkYellow
