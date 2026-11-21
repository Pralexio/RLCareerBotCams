"""Pro camera settings for the bots, from Liquipedia's list of player camera settings.

refresh() keeps cameras.txt current: one line per pro, read by the botcams
BakkesMod plugin, which gives each bot the camera of the player it is named
after (and the "*" line to everyone else).

    * 110 100 -3.0 270 0.35 4.00 1.40
    atow 110 100 -3.0 270 0.40 4.20 1.40

Names are compared without case, spaces or punctuation, so the hub's "Atow."
finds Liquipedia's "Atow". One request a week at most; a failed download
keeps the list already on disk.

Self-check: python cameras.py   (add --fetch to force a download)
"""

import gzip
import html
import json
import re
import time
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "cameras.txt"
URL = ("https://liquipedia.net/rocketleague/api.php?action=parse"
       "&page=List_of_player_camera_settings&prop=text&format=json")
FIELDS = ("FOV", "Height", "Angle", "Distance", "Stiffness", "Swivel speed", "Transition speed")
WEEK = 7 * 24 * 3600


def slug(text):
    return re.sub(r"[^a-z0-9]", "", text.lower())


def parse(page_html):
    """{slug: [seven numbers as text]} from the list's table."""
    cameras = {}
    for row in page_html.split("<tr")[1:]:
        cells = {label: html.unescape(re.sub(r"<[^>]+>", "", value)).strip()
                 for label, value in re.findall(r'<td data-label="([^"]+)"[^>]*>(.*?)</td>', row, re.S)}
        values = [cells.get(field, "") for field in FIELDS]
        key = slug(cells.get("Player", ""))
        if key and all(re.fullmatch(r"-?\d+(\.\d+)?", v) for v in values):
            cameras[key] = values
    return cameras


def download():
    # Liquipedia's API terms: a named client and gzip. No personal details in it.
    request = urllib.request.Request(URL, headers={
        "User-Agent": "RLCareerBotCams/1.0 (personal offline mod; one request per week)",
        "Accept-Encoding": "gzip"})
    with urllib.request.urlopen(request, timeout=15) as response:
        body = response.read()
        if response.headers.get("Content-Encoding") == "gzip":
            body = gzip.decompress(body)
    return json.loads(body)["parse"]["text"]["*"]


def refresh(force=False):
    if not force and OUT.exists() and time.time() - OUT.stat().st_mtime < WEEK:
        return
    cameras = parse(download())
    if len(cameras) < 100:
        raise ValueError(f"only {len(cameras)} cameras read: page layout changed? kept the old list")
    config_path = HERE / "config.json"  # optional: {"defaultCamera": "vatira"}
    config = json.loads(config_path.read_text(encoding="utf-8")) if config_path.exists() else {}
    default = cameras.get(slug(config.get("defaultCamera", "zen"))) or cameras["zen"]
    lines = ["* " + " ".join(default)] + [f"{key} {' '.join(v)}" for key, v in sorted(cameras.items())]
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"[botcams] {len(cameras)} pro cameras written", flush=True)


if __name__ == "__main__":
    import sys

    sample = ('<tr><td data-label="Player"><b> <a href="/x">Atow</a></b> </td><td data-label="FOV">110</td>'
              '<td data-label="Height">100</td><td data-label="Angle">-3.0</td><td data-label="Distance">270</td>'
              '<td data-label="Stiffness">0.40</td><td data-label="Swivel speed">4.20</td>'
              '<td data-label="Transition speed">1.40</td></tr>'
              '<tr><td data-label="Player">Broken</td><td data-label="FOV">?</td></tr>')
    assert parse(sample) == {"atow": ["110", "100", "-3.0", "270", "0.40", "4.20", "1.40"]}
    assert slug("Atow.") == slug("atow") and slug("M0nkey M00n") == "m0nkeym00n"
    print("cameras self-check ok")
    if "--fetch" in sys.argv:
        refresh(force=True)
    elif "--refresh" in sys.argv:  # started by the botcams plugin: only if the list is a week old
        refresh()
