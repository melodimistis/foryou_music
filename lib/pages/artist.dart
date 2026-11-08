import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/format.dart';
import '../models/album.dart';
import '../providers/library_controller.dart';
import '../providers/player_controller.dart';
import '../widgets/cover_art.dart';
import '../widgets/detail_scaffold.dart';
import '../widgets/media_row.dart';
import 'album.dart';

class ArtistPage extends StatelessWidget {
  const ArtistPage({super.key, required this.artistId});

  final String artistId;

  static Future<void> open(BuildContext context, Artist artist) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => ArtistPage(artistId: artist.id)));

  @override
  Widget build(BuildContext context) {
    final artist = context.select<LibraryController, Artist?>(
      (l) => l.artistById(artistId),
    );
    final currentId = context.select<PlayerController, String?>(
      (p) => p.current?.id,
    );

    if (artist == null) {
      return const DetailScaffold(
        title: 'Artists',
        body: Center(
          child: Text(
            'This artist is no longer in your library',
            style: TextStyle(color: Colors.white38, fontFamily: 'Inter'),
          ),
        ),
      );
    }

    return DetailScaffold(
      title: 'Artists',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          _Header(artist: artist),
          if (artist.albums.isNotEmpty) ...[
            const _SectionTitle('Albums'),
            SizedBox(
              height: 172,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: artist.albums.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (context, i) {
                  final album = artist.albums[i];
                  return _AlbumTile(
                    album: album,
                    onTap: () => AlbumPage.open(context, album),
                  );
                },
              ),
            ),
          ],
          const _SectionTitle('Songs'),
          for (final (i, song) in artist.songs.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: MediaRow(
                title: song.title,
                subtitle: song.album,
                coverKey: song.coverKey,
                trailing: formatDuration(song.durationMs),
                active: song.id == currentId,
                enabled: song.available,
                onTap: () => context.read<PlayerController>().playQueue(
                  artist.songs,
                  startIndex: i,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.artist});

  final Artist artist;

  @override
  Widget build(BuildContext context) {
    final count = artist.songs.length;
    return SizedBox(
      height: 280,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Opacity(
                opacity: 0.45,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: CoverArt(
                    coverKey: artist.coverKey,
                    size: 200,
                    radius: 0,
                  ),
                ),
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CoverArt(coverKey: artist.coverKey, size: 150, circle: true),
              const SizedBox(height: 14),
              Text(
                artist.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Inter',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  if (artist.genres.isNotEmpty) joinNatural(artist.genres),
                  '$count ${count == 1 ? 'song' : 'songs'}',
                ].join(' · '),
                style: const TextStyle(
                  color: Colors.white70,
                  fontFamily: 'Inter',
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlbumTile extends StatelessWidget {
  const _AlbumTile({required this.album, required this.onTap});

  final Album album;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoverArt(coverKey: album.coverKey, size: 120, radius: 10),
            const SizedBox(height: 6),
            Text(
              album.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Inter',
                fontSize: 14,
              ),
            ),
            if (album.year != null)
              Text(
                '${album.year}',
                style: const TextStyle(
                  color: Colors.white54,
                  fontFamily: 'Inter',
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
