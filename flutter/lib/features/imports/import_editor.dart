import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:material_ui/material_ui.dart';

import '../library/track_actions.dart';
import 'import_draft.dart';
import 'import_selection.dart';

/// Form values live in the session draft, including while this widget is absent.
class ImportEditor extends StatelessWidget {
  const ImportEditor({super.key, required this.selection, required this.draft});
  final ImportSelection selection;
  final ImportDraft draft;

  bool get editable => !selection.backend.busy && !draft.locked;
  void change(void Function(ImportDraft) update) =>
      selection.update(draft, update);

  Future<void> _artwork() => selection.loadArtwork(draft, () async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'Обложка',
          extensions: ['png', 'jpg', 'jpeg', 'webp'],
        ),
      ],
    );
    if (file == null) return null;
    if (await file.length() > 8 * 1024 * 1024) {
      throw const FormatException('Обложка должна быть не больше 8 МиБ');
    }
    return file.readAsBytes();
  });

  Future<void> _lyrics() => selection.loadLyrics(draft, () async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'Текст песни',
          extensions: ['lrc', 'srt', 'vtt', 'txt'],
        ),
      ],
    );
    if (file == null) return null;
    if (await file.length() > 128 * 1024) {
      throw const FormatException('Текст должен быть не больше 128 КиБ');
    }
    final bytes = await file.readAsBytes();
    return (
      text: utf8.decode(bytes),
      format: file.name.split('.').last.toLowerCase(),
    );
  });

  @override
  Widget build(BuildContext context) {
    final preview = draft.preview;
    final cover = draft.clearArtwork
        ? null
        : draft.artwork ?? preview?.artwork?.bytes;
    final busy = selection.backend.busy;
    if (draft.applied) {
      return ListTile(
        leading: const Icon(Icons.check_circle_outline),
        title: Text(draft.fields['title'] ?? draft.filename),
        subtitle: const Text('Импорт подтверждён'),
        trailing: IconButton(
          tooltip: 'Убрать из черновиков',
          onPressed: busy ? null : () => selection.discard(draft),
          icon: const Icon(Icons.close),
        ),
      );
    }
    return ExpansionTile(
      key: PageStorageKey('import-editor-${draft.id}'),
      initiallyExpanded: !draft.applied,
      title: Text(
        draft.fields['title']?.trim().isNotEmpty == true
            ? draft.fields['title']!
            : draft.filename,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        draft.applied
            ? 'Импорт подтверждён'
            : draft.review != null
            ? 'Требуется решение о дубликате'
            : draft.command != null
            ? commandMessage(draft.command!)
            : draft.locked
            ? 'Результат отправки пока не подтверждён'
            : 'Черновик · ${draft.filename}',
      ),
      childrenPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (draft.locked && !draft.applied)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Редактирование заблокировано после начала отправки. Повтор использует сохранённые данные. Отмена ожидания не отменяет уже принятый импорт.',
            ),
          ),
        if (draft.recoveredWithoutRequest)
          const Text(
            'Найден подготовленный файл без локального запроса. Можно проверить состояние и продолжить операцию из журнала; изменить данные здесь нельзя.',
          ),
        if (preview != null) ...[
          Text(
            '${preview.metadata.codec.toUpperCase()} · '
            '${(preview.sizeBytes.toDouble() / (1024 * 1024)).toStringAsFixed(1)} МиБ',
          ),
          for (final warning in preview.warnings) Text(warning),
        ],
        if (draft.fields.isNotEmpty) ...[
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth >= 600
                  ? (constraints.maxWidth - 16) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final field in const {
                    'title': 'Название',
                    'artist': 'Исполнитель',
                    'album': 'Альбом',
                    'albumArtist': 'Исполнитель альбома',
                    'year': 'Год',
                    'genre': 'Жанр',
                    'trackNumber': 'Номер трека',
                    'discNumber': 'Номер диска',
                    'composer': 'Композитор',
                    'comment': 'Комментарий',
                    'copyright': 'Авторские права',
                  }.entries)
                    SizedBox(
                      width: width,
                      child: TextFormField(
                        key: ValueKey('import-${draft.id}-${field.key}'),
                        initialValue: draft.fields[field.key],
                        enabled: editable,
                        decoration: InputDecoration(labelText: field.value),
                        onChanged: (value) =>
                            change((d) => d.fields[field.key] = value),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Text('Обложка', style: Theme.of(context).textTheme.titleMedium),
          if (cover != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Image.memory(
                cover,
                width: 120,
                height: 120,
                fit: BoxFit.contain,
                cacheWidth: 240,
                errorBuilder: (_, _, _) => const Text(
                  'Не удалось прочитать обложку. Выберите другой файл.',
                ),
              ),
            )
          else
            Text(draft.clearArtwork ? 'Обложка будет удалена' : 'Нет обложки'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: editable ? _artwork : null,
                child: const Text('Выбрать обложку'),
              ),
              TextButton(
                onPressed: editable && cover != null
                    ? () => change((d) {
                        d.artwork = null;
                        d.clearArtwork = true;
                      })
                    : null,
                child: const Text('Удалить обложку'),
              ),
              TextButton(
                onPressed: editable
                    ? () => change((d) {
                        d.artwork = null;
                        d.clearArtwork = false;
                      })
                    : null,
                child: const Text('Исходная обложка'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Текст песни', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            key: ValueKey(
              'lyrics-mode-${draft.id}-${draft.clearLyrics}-${draft.replaceLyrics}',
            ),
            initialValue: draft.clearLyrics
                ? 'clear'
                : draft.replaceLyrics
                ? 'replace'
                : 'keep',
            decoration: const InputDecoration(),
            items: const [
              DropdownMenuItem(
                value: 'keep',
                child: Text('Сохранить встроенный текст'),
              ),
              DropdownMenuItem(value: 'replace', child: Text('Заменить текст')),
              DropdownMenuItem(value: 'clear', child: Text('Удалить текст')),
            ],
            onChanged: editable
                ? (value) => change((d) {
                    d.replaceLyrics = value == 'replace';
                    d.clearLyrics = value == 'clear';
                  })
                : null,
          ),
          const SizedBox(height: 12),
          if (!draft.replaceLyrics && !draft.clearLyrics)
            Text(
              preview?.lyrics == null
                  ? 'Встроенного текста нет'
                  : 'Встроенный текст: ${preview!.lyrics!.lines.length} строк',
            ),
          if (!draft.replaceLyrics &&
              !draft.clearLyrics &&
              preview?.lyrics != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 8, bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                preview!.lyrics!.lines
                    .where((line) => line.text.trim().isNotEmpty)
                    .take(6)
                    .map((line) => line.text)
                    .join('\n'),
                style: const TextStyle(height: 1.5),
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          TextButton.icon(
            onPressed: editable ? _lyrics : null,
            icon: const Icon(Icons.upload_file),
            label: const Text('Загрузить LRC / SRT / VTT / TXT'),
          ),
          if (draft.replaceLyrics && !draft.clearLyrics) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              key: ValueKey('lyrics-format-${draft.id}-${draft.lyricsFormat}'),
              initialValue: draft.lyricsFormat,
              decoration: const InputDecoration(labelText: 'Формат текста'),
              items: const [
                DropdownMenuItem(value: 'lrc', child: Text('LRC')),
                DropdownMenuItem(value: 'srt', child: Text('SRT')),
                DropdownMenuItem(value: 'vtt', child: Text('WebVTT')),
                DropdownMenuItem(value: 'plain', child: Text('Обычный текст')),
                DropdownMenuItem(value: 'txt', child: Text('TXT')),
              ],
              onChanged: editable
                  ? (value) => change((d) => d.lyricsFormat = value!)
                  : null,
            ),
            const SizedBox(height: 16),
            // Importing a file must replace a mounted form's old text too.
            _LyricsInput(selection: selection, draft: draft),
          ],
          const SizedBox(height: 20),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Записать теги в загружаемую копию'),
            subtitle: const Text(
              'Исходный файл не изменяется. При выключении изменения сохранятся только в медиатеке KIYORA.',
            ),
            value: draft.writeTags,
            onChanged: editable
                ? (value) => change((d) => d.writeTags = value)
                : null,
          ),
        ],
        if (draft.review != null) ...[
          const SizedBox(height: 12),
          Text(
            'Найдены дубликаты: ${draft.review!.duplicateTrackIds.length}; похожие треки: ${draft.review!.possibleDuplicateTrackIds.length}.',
          ),
          const Text('Добавить отдельную копию с подготовленными изменениями?'),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            if (!draft.applied && (draft.preview != null || draft.locked))
              FilledButton(
                onPressed: busy
                    ? null
                    : () => selection.submit(
                        draft,
                        confirmDuplicate: draft.review != null,
                      ),
                child: Text(
                  draft.review != null
                      ? 'Импортировать дубликат'
                      : draft.locked
                      ? 'Повторить отправку'
                      : 'Импортировать с изменениями',
                ),
              ),
            if (!draft.locked && draft.preview == null)
              FilledButton(
                onPressed: busy ? null : () => selection.retryPreview(draft),
                child: const Text('Повторить подготовку'),
              ),
            if (!draft.locked || draft.applied || draft.review != null)
              TextButton(
                onPressed: busy ? null : () => selection.discard(draft),
                child: Text(
                  draft.applied ? 'Убрать из черновиков' : 'Отменить импорт',
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _LyricsInput extends StatefulWidget {
  const _LyricsInput({required this.selection, required this.draft});
  final ImportSelection selection;
  final ImportDraft draft;
  @override
  State<_LyricsInput> createState() => _LyricsInputState();
}

class _LyricsInputState extends State<_LyricsInput> {
  late final _text = TextEditingController(text: widget.draft.lyricsText);
  @override
  void didUpdateWidget(covariant _LyricsInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_text.text != widget.draft.lyricsText)
      _text.text = widget.draft.lyricsText;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _text,
    enabled: !widget.selection.backend.busy && !widget.draft.locked,
    minLines: 4,
    maxLines: 10,
    decoration: InputDecoration(
      labelText:
          widget.draft.lyricsFormat == 'plain' ||
              widget.draft.lyricsFormat == 'txt'
          ? 'Текст песни'
          : 'Текст и временные метки',
      alignLabelWithHint: true,
      hintText: widget.draft.lyricsFormat == 'lrc'
          ? '[00:12.00]Первая строка песни'
          : null,
      floatingLabelBehavior: FloatingLabelBehavior.always,
    ),
    onChanged: (value) =>
        widget.selection.update(widget.draft, (d) => d.lyricsText = value),
  );
}
