# TikTok Video Downloader

This tool parses the JSON version of the TikTok user data (typically named user_data.json) and downloads all the video files to a local folder.

## Instructions

First, [request a copy of your data](https://support.tiktok.com/en/account-and-privacy/personalized-ads-and-data/requesting-your-data) from TikTok, make sure you select the *JSON* format.

Next, wait until you receive an email from TikTok telling you that your data is ready.

Now download the ZIP file to your computer and unzip, you should end up with a file called **user_data.json**, this file could be quite large and I recommend not trying to open it in your text editor. Follow the instructions below to run this tool against the JSON file.

## CLI Arguments

Format: **tiktok.py** filename.json -d /path/to/folder -v

* filename.json: Path to the TikTok user data JSON file
* -d, --dest: Video download destination path
* -v, --verbose: Enables verbose logging

## Data Structure

Just in case you're curious, this is what the data structure looks like.

```yaml
Activity:
  Video:
    Videos:
      VideoList:
        - Date:
          Likes:
          Link:
```

## Requirements

* Python 3

## Credits

Thanks to @thebeardeditguy for showing the community this method!
