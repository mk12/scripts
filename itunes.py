#!/usr/bin/env python3

"""This script prints top-played songs from iTunes for each year."""

from collections import defaultdict
from dateutil.parser import parse
from pathlib import Path
import xml.etree.ElementTree as ET

LIBRARY = Path.home() / "Music/iTunes/iTunes Library.xml"


def plist_iter(iterable, all_dicts=False):
    a = iter(iterable)
    for k, v in zip(a, a):
        assert k.tag == "key"
        if all_dicts:
            if v.tag != "dict":
                print(f"For key {k.text}, not dict but {v.tag}")
            assert v.tag == "dict"
        yield k.text, v


def extract_songs(tree):
    root = tree.getroot()[0]
    tracks = None
    for key, node in plist_iter(root):
        if key == "Tracks":
            tracks = node
    songs = []
    for key, node in plist_iter(tracks, all_dicts=True):
        is_music = False
        song = {}
        for k, n in plist_iter(node):
            if k == "Kind":
                if "audio" in n.text:
                    is_music = True
                else:
                    break
            elif k in ("Podcast", "Movie", "Audiobooks"):
                is_music = False
                break
            elif k == "Play Count":
                song["play_count"] = int(n.text)
            elif k == "Date Added":
                song["date_added"] = parse(n.text)
            elif k == "Name":
                if "wcpe" in n.text.lower():
                    is_music = False
                    break
                song["name"] = n.text
            elif k == "Album":
                song["album"] = n.text
            elif k == "Artist":
                song["artist"] = n.text
        if is_music:
            songs.append(song)
    return songs


def make_playlists(songs):
    by_year = defaultdict(list)
    for song in songs:
        if "date_added" in song and "play_count" in song:
            by_year[song["date_added"].year].append(song)
    for _, song_list in by_year.items():
        song_list.sort(key=lambda s: s["play_count"], reverse=True)
    return by_year


def print_top_songs(playlists):
    for year in range(2010, 2020):
        print(f"{year}\n====")
        for i, song in enumerate(playlists[year][:25]):
            play_count = song["play_count"]
            name = song.get("name", "Unknown name")
            artist = song.get("artist", "Unknown artist")
            album = song.get("album", "Unknown album")
            print(f"{i+1}. [{play_count}] {name}  |  {artist}  |  {album}")
        print("\n\n")


def main():
    tree = ET.parse(LIBRARY)
    songs = extract_songs(tree)
    playlists = make_playlists(songs)
    print_top_songs(playlists)


if __name__ == "__main__":
    main()
