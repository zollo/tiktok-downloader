"""
Python script that aids in parsing TikTok's user data
JSON and downloading the raw video files it references.
"""

import json
import argparse
from urllib.parse import urlparse, parse_qs
from pathlib import Path
import logging
import urllib3

http = urllib3.PoolManager()
parser = argparse.ArgumentParser(
    prog="tiktok.py", description="Parses TikTok JSON Data"
)

# setup cli args
parser.add_argument("filename")
parser.add_argument("-d", "--dest", default="./videos")
parser.add_argument("-v", "--verbose", default=False, action="store_true")
args = parser.parse_args()

# setup logging
LOG_LEVEL = logging.DEBUG if args.verbose else logging.INFO
logger = logging.getLogger()
logger.setLevel(LOG_LEVEL)


def main():
    """Main Method"""
    with open(file=args.filename, encoding="utf-8") as file:
        data = json.load(file)

    count = 0
    skipped = 0

    # iterate over videolist
    for k in data["Video"]["Videos"]["VideoList"]:
        url = urlparse(k["Link"])
        split = url.path.split("/")
        filename = split[(len(url.path.split("/"))) - 1]
        full_path = f"{args.dest}/{filename}.mp4"

        # check if this file exists, if so, skip iteration
        if Path(full_path).is_file():
            logger.debug(
                "Video {filename} already downloaded! Skipping",
                filename=filename
            )
            skipped += 1
            continue

        # parse the file type using the string url
        params = parse_qs(url.query)

        # check for the mime type identified in the query string
        if params.get("mime_type") and \
                params.get("mime_type")[0] == "video_mp4":
            # download file
            logger.debug(
                "Downloading: {filename} from \
                    {scheme}://{hostname}{path}",
                filename=filename,
                scheme=url.scheme,
                hostname=url.hostname,
                path=url.path,
            )
            req = http.request("GET", k["Link"], redirect=True)

            # write file to destination path
            logger.debug("Writing to: {full_path}", full_path=full_path)
            with open(file=full_path, mode="wb") as file:
                file.write(req.data)

            # increment count
            count += 1

            # clear memory
            del req

    logger.info("Parsed File Successfully")
    logger.info("Downloaded {count} file(s)", count=count)
    logger.info("Skippped {skipped} file(s)", skipped=skipped)


if __name__ == "__main__":
    main()
