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
- **Lyrics that follow along.** Timed `.lrc` files scroll with the song, and the enhanced format lights up word by word.
- **Library you can browse.** Songs, albums, artists and playlists, with search, favourites and a fast scroller for big collections.
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

### Covers

ForYou uses the picture embedded in the song first. If there isn't one, it looks for `cover.jpg`, `folder.jpg` or `front.jpg` (or `.png`) in the song's folder.

## Good to know

- **Audio Quality** in Settings says "Soon" on purpose. There are no audio options yet; files are played as they are, with nothing added.
- **Songs can't be deleted from the app.** ForYou only reads your files and never changes them. Delete with your file manager, then rescan.
- **"Artist feat. Someone" shows up as its own artist**, because artists are read exactly as tagged.
- **Music stops when the screen is off?** Some phones put apps to sleep. On Samsung, remove ForYou from *Sleeping apps* in battery settings; elsewhere, set its battery usage to *Unrestricted*.

More answers are in the app under **Settings > Help**.

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

## Someday

Support for your own music server, so the library you host at home can play here too. It's planned, not promised, and won't hold up other releases.

## Reporting problems

Open an issue on [GitHub Issues](https://github.com/melodimistis/foryou_music/issues). **Settings > Help > Copy app info** copies your app version and system details so you can paste them into the report.

For anything else, email the developer at azaralfy01@gmail.com.

## License

ForYou Music is free software under the GNU General Public License version 3 only (GPL-3.0-only). See [LICENSE](LICENSE).

The ForYou Music name, logo and the Yoru character are not covered by the GPL. If you fork the project, please give it a different name and logo. The Inter font is under the SIL Open Font License 1.1 (`assets/fonts/OFL.txt`). Licenses of the packages ForYou uses are listed in the app under **Legal > Third-party licenses**.

---

<p align="center">Develop & Maintenance with <a href="https://github.com/melodimistis">melodimistis</a></p>
