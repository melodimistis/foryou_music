import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/format.dart';
import '../models/song.dart';
import '../providers/library_controller.dart';
import '../providers/player_controller.dart';
import '../services/song_search.dart';
import '../pages/album.dart';
import '../pages/artist.dart';
import 'context_menu.dart';
import 'cover_art.dart';
import 'menu_actions.dart';

class SearchView extends StatefulWidget {
  const SearchView({super.key, this.active = true});

  final bool active;

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  String _query = '';
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.active) _focusSoon();
  }

  @override
  void didUpdateWidget(SearchView old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _focusSoon();
    if (!widget.active && old.active) _focus.unfocus();
  }

  void _focusSoon() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && widget.active) _focus.requestFocus();
  });

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final songs = context.select<LibraryController, List<Song>>((l) => l.songs);
    final results = searchSongs(songs, _query);
    final lib = context.read<LibraryController>();
    final artists = searchArtists(lib.artists, _query);
    final albums = searchAlbums(lib.albums, _query);
    final currentId = context.select<PlayerController, String?>(
      (p) => p.current?.id,
    );

    return Column(
      children: [
        TextField(
          focusNode: _focus,
          onChanged: (v) => setState(() => _query = v),
          textInputAction: TextInputAction.search,
          style: const TextStyle(color: Colors.white, fontFamily: 'Inter'),
          decoration: InputDecoration(
            filled: true,
            isDense: true,
            fillColor: Colors.white.withValues(alpha: 0.08),
            hintText: 'Hmm... Any idea?',
            hintStyle: const TextStyle(color: Colors.white38),
            suffixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _query.trim().isEmpty
              ? const _Hint('Type to find your rhythm...')
              : results.isEmpty && artists.isEmpty && albums.isEmpty
              ? _Hint('Nothing found for "${_query.trim()}"')
              : ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    if (artists.isNotEmpty) ...[
                      const _Section('Artists'),
                      for (final a in artists)
                        _EntityRow(
                          title: a.name,
                          subtitle: joinNatural(a.genres),
                          coverKey: a.coverKey,
                          circle: true,
                          onTap: () => ArtistPage.open(context, a),
                        ),
                    ],
                    if (albums.isNotEmpty) ...[
                      const _Section('Albums'),
                      for (final a in albums)
                        _EntityRow(
                          title: a.title,
                          subtitle: artistOrUnknown(a.artist),
                          coverKey: a.coverKey,
                          onTap: () => AlbumPage.open(context, a),
                        ),
                    ],
                    if (results.isNotEmpty &&
                        (artists.isNotEmpty || albums.isNotEmpty))
                      const _Section('Songs'),
                    for (final (i, s) in results.indexed)
                      MenuTarget(
                        actions: (context) => songActions(context, s),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: s.available
                              ? () => context
                                    .read<PlayerController>()
                                    .playQueue(results, startIndex: i)
                              : null,
                          child: Opacity(
                            opacity: s.available ? 1 : 0.4,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          s.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontFamily: 'Inter',
                                            fontSize: 15,
                                            fontWeight: s.id == currentId
                                                ? FontWeight.w700
                                                : FontWeight.w400,
                                          ),
                                        ),
                                        Text(
                                          artistOrUnknown(s.artist),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontFamily: 'Inter',
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  MenuButton(
                                    actions: (context) =>
                                        songActions(context, s),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 6),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white54,
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EntityRow extends StatelessWidget {
  const _EntityRow({
    required this.title,
    required this.subtitle,
    required this.coverKey,
    required this.onTap,
    this.circle = false,
  });

  final String title;
  final String subtitle;
  final String coverKey;
  final VoidCallback onTap;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: Row(
          children: [
            CoverArt(coverKey: coverKey, size: 40, radius: 8, circle: circle),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Inter',
                      fontSize: 15,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontFamily: 'Inter',
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white38, fontFamily: 'Inter'),
      ),
    );
  }
}
