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

Function Get-TikTokDownload {
    param($Uri,$OutFile,$Date,$File)

    # parse video post
    try {
        $dl = New-Object System.Net.WebClient
        $dl.DownloadFile($Uri, $OutFile)

        # verify file integrity
        $dl_file = Get-Item -LiteralPath $OutFile

        # compare length to expected legnth
        if($dl_file.Length -eq $dl.ResponseHeaders['Content-Length']) {
            # write success log entry
            Write-Host "[INFO][$File] Downloaded file to $OutFile"
        } else {
            # throw error
            Write-Error "[ERROR][$File] Downloaded file size doesn't match expected length!"
            throw "Downloaded file size doesn't match expected content length!"
        }

        # set the creation date from json metadata
        (Get-ChildItem $OutFile).CreationTime = $Date
    } catch {
        # save exception data
        $status = $_.Exception.Response.StatusCode.value__

        # write error to console
        Write-Error "[ERROR][$File] Failed to download - HTTP Error $status"

        # cleanup partially downloaded file
        if(Test-Path -LiteralPath $OutFile) {
            Remove-Item -LiteralPath $OutFile -Force
        }
    }
}

# loop over videos and download
$json.Video.Videos.VideoList | ForEach-Object {
    # generate http url
    $uri = $_.Link

    # generate unique file name by removing invalid characters
    $filename = $_.Date.replace(" ", "-").replace(":","-") + ".mp4"
    $full_path = "$OutputFolder\$filename"

    # parse date field
    $date = [datetime]::ParseExact($_.Date, "yyyy-MM-dd HH:mm:ss", $null)

    # check if path exists
    if(Test-Path -LiteralPath $full_path) {
        # get filesize of existing file
        $filedata = Get-Item -LiteralPath $full_path

        # cleanup erroneous files less than 1000 bytes
        if($filedata.Length -lt 1000) {
            Remove-Item -LiteralPath $full_path -Force
        }
    }

    if($uri -eq "N/A") {
        # parse erroneous post
        Write-Host "[INFO][$filename] has no available link, skipping." `
            -ForegroundColor Cyan
    } elseif($uri.split(' ').Length -gt 1) {
        # parse photos post
        Write-Host "[INFO][$filename] is a photos post, skipping." `
            -ForegroundColor DarkMagenta
    } else {
        # check if file already exists
        if(-not (Test-Path $full_path) -or $Force) {
            # generate thread job
            $jobs += Start-ThreadJob -StreamingHost $Host -Name $filename -ScriptBlock {
                $params = @{
                    Uri = $using:uri
                    File = $using:filename
                    OutFile = $using:OutputFolder
                    Date = $using:date
                }

                # parse video post
                Get-TikTokDownload @params
            }
        } else {
            if($Verbose) {
                Write-Host "[INFO][$filename] already downloaded, skipping!" `
                    -ForegroundColor DarkCyan
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
