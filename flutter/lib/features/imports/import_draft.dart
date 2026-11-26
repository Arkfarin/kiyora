import 'dart:convert';
import 'dart:typed_data';

import '../../core/bridge/generated/api/content.dart' as content;
import '../../core/bridge/generated/api/edits.dart' as edits;
import '../../core/bridge/generated/api/imports.dart' as imports;
import '../../core/bridge/generated/api/jobs.dart' as jobs;

/// Only editor state lives here. Staged audio and import receipts belong to Rust.
class ImportDraft {
  ImportDraft({
    required this.id,
    required this.trackId,
    required this.sourceId,
    required this.path,
    required this.filename,
  });

  factory ImportDraft.fromFile(jobs.ImportFile file) => ImportDraft(
    id: file.operationId,
    trackId: file.trackId,
    sourceId: file.sourceId,
    path: file.path,
    filename: file.path.split('/').last,
  );

  final String id;
  final String trackId;
  final String sourceId;
  final String path;
  final String filename;
  imports.Preview? preview;
  Map<String, String> fields = {};
  Uint8List? artwork;
  bool clearArtwork = false;
  String lyricsText = '';
  String lyricsFormat = 'lrc';
  bool replaceLyrics = false;
  bool clearLyrics = false;
  bool writeTags = false;
  bool allowDuplicate = false;
  bool recoveredWithoutRequest = false;
  PreparedRequest? request;
  jobs.ImportReview? review;
  edits.Command? command;
  bool get locked => request != null || recoveredWithoutRequest;
  bool get applied => command?.state == edits.CommandState.applied;

  void attach(imports.Preview value) {
    preview = value;
    if (fields.isNotEmpty) return;
    final m = value.metadata;
    fields = {
      'title': m.title,
      'artist': m.artist,
      'album': m.album,
      'albumArtist': m.albumArtist,
      'year': '${m.year}',
      'genre': m.genre,
      'trackNumber': '${m.trackNumber}',
      'discNumber': '${m.discNumber}',
      'composer': m.composer,
      'comment': m.comment,
      'copyright': m.copyright,
    };
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'trackId': trackId,
    'sourceId': sourceId,
    'path': path,
    'filename': filename,
    'fields': fields,
    'artwork': artwork == null ? null : base64Encode(artwork!),
    'clearArtwork': clearArtwork,
    'lyricsText': lyricsText,
    'lyricsFormat': lyricsFormat,
    'replaceLyrics': replaceLyrics,
    'clearLyrics': clearLyrics,
    'writeTags': writeTags,
    'allowDuplicate': allowDuplicate,
    'recoveredWithoutRequest': recoveredWithoutRequest,
    'request': request?.toJson(),
  };

  factory ImportDraft.fromJson(Map<String, dynamic> json) {
    final draft = ImportDraft(
      id: json['id'] as String,
      trackId: json['trackId'] as String,
      sourceId: json['sourceId'] as String,
      path: json['path'] as String,
      filename: json['filename'] as String,
    );
    draft.fields = Map<String, String>.from(json['fields'] as Map);
    draft.artwork = json['artwork'] == null
        ? null
        : base64Decode(json['artwork'] as String);
    draft.clearArtwork = json['clearArtwork'] as bool;
    draft.lyricsText = json['lyricsText'] as String;
    draft.lyricsFormat = json['lyricsFormat'] as String;
    draft.replaceLyrics = json['replaceLyrics'] as bool;
    draft.clearLyrics = json['clearLyrics'] as bool;
    draft.writeTags = json['writeTags'] as bool;
    draft.allowDuplicate = json['allowDuplicate'] as bool;
    draft.recoveredWithoutRequest = json['recoveredWithoutRequest'] as bool;
    if (json['request'] != null) {
      draft.request = PreparedRequest.fromJson(
        json['request'] as Map<String, dynamic>,
      );
    }
    return draft;
  }
}

/// Captured once, before the first native commit. Retries never rebuild it from
/// the form, reparse lyrics, or reread an external artwork file.
class PreparedRequest {
  const PreparedRequest(this.edit, this.writeTags);
  final edits.MetadataEdit edit;
  final bool writeTags;

  Map<String, Object?> toJson() => {
    'writeTags': writeTags,
    'title': edit.title,
    'artist': edit.artist,
    'album': edit.album,
    'albumArtist': edit.albumArtist,
    'year': edit.year,
    'genre': edit.genre,
    'trackNumber': edit.trackNumber,
    'discNumber': edit.discNumber,
    'composer': edit.composer,
    'comment': edit.comment,
    'copyright': edit.copyright,
    'artwork': edit.artwork == null ? null : base64Encode(edit.artwork!),
    'clearArtwork': edit.clearArtwork,
    'clearLyrics': edit.clearLyrics,
    'lyrics': edit.lyrics == null
        ? null
        : {
            'language': edit.lyrics!.language,
            'lines': [
              for (final line in edit.lyrics!.lines)
                {
                  'startMs': line.startMs?.toString(),
                  'endMs': line.endMs?.toString(),
                  'text': line.text,
                },
            ],
          },
  };

  factory PreparedRequest.fromJson(Map<String, dynamic> json) {
    final lyrics = json['lyrics'] as Map<String, dynamic>?;
    return PreparedRequest(
      edits.MetadataEdit(
        title: json['title'] as String?,
        artist: json['artist'] as String?,
        album: json['album'] as String?,
        albumArtist: json['albumArtist'] as String?,
        year: json['year'] as int?,
        genre: json['genre'] as String?,
        trackNumber: json['trackNumber'] as int?,
        discNumber: json['discNumber'] as int?,
        composer: json['composer'] as String?,
        comment: json['comment'] as String?,
        copyright: json['copyright'] as String?,
        artwork: json['artwork'] == null
            ? null
            : base64Decode(json['artwork'] as String).asUnmodifiableView(),
        clearArtwork: json['clearArtwork'] as bool,
        clearLyrics: json['clearLyrics'] as bool,
        lyrics: lyrics == null
            ? null
            : content.Lyrics(
                language: lyrics['language'] as String?,
                lines: List.unmodifiable(
                  (lyrics['lines'] as List).map(
                    (line) => content.LyricLine(
                      startMs: line['startMs'] == null
                          ? null
                          : BigInt.parse(line['startMs'] as String),
                      endMs: line['endMs'] == null
                          ? null
                          : BigInt.parse(line['endMs'] as String),
                      text: line['text'] as String,
                    ),
                  ),
                ),
              ),
      ),
      json['writeTags'] as bool,
    );
  }
}
