<p align="center">
  <img src="assets/images/foryou_logo.png" alt="ForYou Music logo" width="128">
</p>

<h1 align="center">ForYou Music</h1>

<p align="center">
  A music player for the music you already own.<br>
  <em>For You, By You and All Yours!</em>
</p>

---

ForYou Music plays the songs sitting in your folders. There is no account, no streaming and no ads. Your library, favourites, playlists and play history are kept on your device, and the app shapes itself around what you actually listen to.

It runs on **Android** and **Linux**. Windows builds are possible but not a priority yet.

**Reading this on Codeberg?** Codeberg only holds a copy of the source code. Downloads, release notes, issues and everything else live on GitHub: [github.com/melodimistis/foryou_music](https://github.com/melodimistis/foryou_music).

## What it does

- **Plays your folders.** Add one or more music folders and ForYou scans them, including everything inside. MP3, FLAC, WAV, OGG, OPUS, M4A and AAC are supported.
- **Keeps up with your files.** Rescan picks up new, changed and removed songs. If you move a file somewhere else inside your folders, it keeps its play count, favourite and playlists.
- **Home built from your listening.** "As always", "Recently", "Long time no hear" and picks based on the genres you play most.
- **Lyrics that follow along.** Timed `.lrc` files scroll with the song, and the enhanced format lights up word by word. A second line with the same time, like romanization or a translation, shows smaller underneath.
- **Library you can browse.** Songs, albums, artists and playlists, with search, favourites and a fast scroller for big collections.
- **Your queue, your way.** Play next or add to the queue from any song, album, artist or playlist, then reorder or remove songs in the queue.
- **Play or shuffle a whole album, or all of them.** Albums and playlists have Play and Shuffle buttons. Long press them on an album to keep going through all your albums, once or on repeat.
- **Know what you're hearing.** The player shows the file's format, bit depth, sample rate and bitrate, like `FLAC · 24-bit · 96 kHz`.
- **Songs that flow.** Gapless playback, an optional crossfade of up to 12 seconds, and a soft fade when you play or pause. Songs that follow each other on the same album never crossfade.
- **Sound your way** (Android 9 or newer). A parametric equalizer with up to 10 filters you can drag on a graph, ready-made presets, your own saved presets, and import of [AutoEq](https://github.com/jaakkopasanen/AutoEq) headphone profiles (`ParametricEQ.txt`).
- **Even volume.** Volume normalization uses the ReplayGain info inside your songs to turn loud songs down, per song or per album. Your files are never changed.
- **Take your playlists with you.** Export any playlist or your favourites as an `.m3u` file that VLC, Poweramp, foobar2000 and other players can open.
- **Notes on songs.** Write a short note on a song, like where it takes you back to, and see it in the player.
- **Suggestions that know the time.** Home learns which songs you play at which hour, and songs you keep skipping stay out of the suggestions.
- **No voice notes in your music.** Short clips without an album and folders like WhatsApp Voice Notes or Recordings are hidden. You can hide more folders yourself.
- **Messages from Yoru** (Android). One to three short notifications a day about your own music: a song you haven't heard in a while, a line from lyrics you love, a guess about who's been on repeat. Written on your phone, never sent anywhere. Change or turn them off in Settings > General.
- **Every artist gets credit.** A song by "A feat. B" shows up on both artists' pages instead of creating a new artist for the pair.
- **Plays in the background.** Media notification, lock screen and headset controls on Android; MPRIS on Linux, so media keys and desktop widgets work.
- **Yoru.** A small companion that greets you and listens along. You can turn it off.

Nothing is downloaded from the internet: lyrics and covers come from your own files.

## Install

Downloads are on the [Releases](https://github.com/melodimistis/foryou_music/releases) page.

**Android** (7.0 or newer): download the `.apk`, open it, and allow installing from your browser or file manager when asked.

**Linux**: download the AppImage, make it executable and run it.

```sh
chmod +x ForYou-Music-*.AppImage
./ForYou-Music-*.AppImage
```

It needs `libmpv` for playback and `libfuse2` for the AppImage itself. On Debian and Ubuntu:

```sh
sudo apt install libmpv2 libfuse2
```

### Updates

ForYou checks GitHub once a day for a new version and tells you when one is out. You can turn that off in Settings > General.

- **Android:** tap **Update** on the card. ForYou downloads the new version, checks that the file is intact, and opens the installer; you confirm with one tap. The first time, Android asks you to allow ForYou to install apps.
- **Linux:** the card takes you to the Releases page; download the new AppImage and replace the old one.

Only official builds from GitHub Releases can update each other, because they are signed with the same key.

## Getting your music in

1. Open **Settings > Storage** and tap **Add music folder**.
2. Pick the folder that holds your music. Folders inside it are included, so pick the outer one.
3. Wait for the scan to finish. That's it.

Music on Google Drive or another cloud service needs to be synced or downloaded to a folder on the device first. ForYou only plays local files.

### Lyrics

Put a `.lrc` file with the same name next to the song (`Song.mp3` and `Song.lrc`), or embed the lyrics in the song's tags.

For word-by-word highlighting, give each word its own time:

```
[00:12.00]<00:12.00>Hello <00:12.40>darkness <00:13.10>my <00:13.40>old <00:13.80>friend
```

For romanization or a translation, add a second line with the same time right below the original. It shows smaller, under the lyric:

```
[00:16.00]사랑해
[00:16.00]saranghae
```

### Covers

ForYou uses the picture embedded in the song first. If there isn't one, it looks for `cover.jpg`, `folder.jpg` or `front.jpg` (or `.png`) in the song's folder.

You can also pick your own picture for any song, album, artist or playlist with **Change cover** in its menu. For an album, choose whether the cover goes on every song or only on songs that have none. ForYou keeps a copy of the picture; your music files are never changed. **Use original cover** brings the old one back.

## Privacy

ForYou collects nothing. The only connection it makes is to GitHub, to check for a new version and, when you tap Update on Android, to download it. It sends nothing about you or your music. The full statement is in the app under **Legal**.

## Building from source

You need Flutter 3.44 or newer (Dart 3.12).

```sh
git clone https://github.com/melodimistis/foryou_music.git
cd foryou_music
flutter pub get
flutter run
```

For Linux you also need the usual Flutter desktop packages plus mpv's development files:

```sh
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev libmpv-dev
```

Run the tests with `flutter test`.

Release builds for Android are signed with a key that is not part of this repository. Without `android/key.properties`, `flutter build apk --release` falls back to the debug key, which is fine for trying things out but can't update an installed official build.

## Soon Feature

Planned for the next updates. These are plans, not promises, and none of them will hold up other releases.

- **The equalizer on Linux.**
- **A better output picker** for headphones and speakers, in ForYou's own style.
- **More of Yoru**: its own artwork and voice, a home screen widget on Android, and an ambient mode.
- **Smaller Android downloads**, with a separate file for each type of phone.
- **Your own music server**, so the library you host at home (Navidrome, Jellyfin and the like) can play here too.

## Reporting problems

Many answers are already in the app under **Settings > Help**. If yours isn't, open an issue on [GitHub Issues](https://github.com/melodimistis/foryou_music/issues). **Settings > Help > Copy app info** copies your app version and system details so you can paste them into the report.

For anything else, email the developer at azaralfy01@gmail.com.

## License

ForYou Music is free software under the GNU General Public License version 3 only (GPL-3.0-only). See [LICENSE](LICENSE).

The ForYou Music name, logo and the Yoru character are not covered by the GPL. If you fork the project, please give it a different name and logo. The Inter font is under the SIL Open Font License 1.1 (`assets/fonts/OFL.txt`). Licenses of the packages ForYou uses are listed in the app under **Legal > Third-party licenses**.

---

<p align="center">Develop & Maintenance with <a href="https://github.com/melodimistis">melodimistis</a></p>
