import 'package:file_selector/file_selector.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/bridge/generated/api/jobs.dart' as jobs;
import '../../core/state/backend_controller.dart';
import '../library/track_actions.dart';
import 'import_selection.dart';
import 'import_editor.dart';

class ImportView extends StatefulWidget {
  const ImportView({super.key, required this.backend, this.selection});
  final BackendController backend;
  final ImportSelection? selection;
  @override
  State<ImportView> createState() => _ImportViewState();
}

class _ImportViewState extends State<ImportView> {
  late Future<List<jobs.Job>> _jobs;
  bool _selecting = false;
  late final ImportSelection _selection;
  BackendController get b => widget.backend;
  @override
  void initState() {
    super.initState();
    _selection = widget.selection ?? ImportSelection(b);
    _refresh();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_selection.restored) _selection.restore();
    });
    b.jobRevision.addListener(_refresh);
  }

  @override
  void dispose() {
    b.jobRevision.removeListener(_refresh);
    if (widget.selection == null) _selection.dispose();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    final pending = jobs.list(sessionId: b.sessionId);
    setState(() {
      _jobs = pending;
    });
  }

  Future<void> _pick() async {
    setState(() => _selecting = true);
    try {
      final files = await openFiles(
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'Музыка',
            extensions: [
              'mp3',
              'flac',
              'm4a',
              'ogg',
              'opus',
              'wav',
              'aac',
              'aiff',
              'alac',
            ],
            mimeTypes: ['audio/*'],
          ),
        ],
      );
      if (files.isEmpty || !mounted) return;
      await _selection.select(files.map((file) => file.path).toList());
    } catch (e) {
      await b.action(() async {
        throw e;
      });
    } finally {
      if (mounted) setState(() => _selecting = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([b, _selection]),
    builder: (context, _) => CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Добавьте свою музыку',
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Выберите файлы. Загрузка продолжится, пока приложение открыто; состояние операций сохраняет KIYORA.',
                ),
                const SizedBox(height: 16),
                if (b.error != null) Text(b.error.toString()),
                if (_selection.saveError != null) ...[
                  const Text(
                    'Не удалось сохранить черновики на диске. Не закрывайте приложение до повторного сохранения.',
                  ),
                  TextButton(
                    onPressed: b.busy ? null : _selection.saveDrafts,
                    child: const Text('Повторить сохранение'),
                  ),
                ],
                Wrap(
                  spacing: 12,
                  children: [
                    TextButton.icon(
                      onPressed: b.busy ? null : _selection.restore,
                      icon: const Icon(Icons.refresh),
                      label: Text(
                        _selection.restored
                            ? 'Проверить состояние импорта'
                            : 'Восстановить черновики',
                      ),
                    ),
                    if (b.busy)
                      TextButton(
                        onPressed: b.cancel,
                        child: const Text('Отменить ожидание'),
                      ),
                  ],
                ),
                if (b.busy) const LinearProgressIndicator(),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed:
                      _selecting ||
                          b.busy ||
                          !_selection.restored ||
                          _selection.files.isNotEmpty
                      ? null
                      : _pick,
                  icon: const Icon(Icons.audio_file_outlined),
                  label: const Text('Выбрать файлы'),
                ),
                if (_selecting) const LinearProgressIndicator(),
                if (_selection.files.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('Выбрано файлов: ${_selection.files.length}'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: b.busy ? null : _selection.send,
                    child: Text(
                      !_selection.retrying
                          ? 'Отправить как есть'
                          : 'Продолжить отправку',
                    ),
                  ),
                  TextButton(
                    onPressed: b.busy || _selection.retrying
                        ? null
                        : _selection.clear,
                    child: const Text('Отменить выбор'),
                  ),
                ],
              ],
            ),
          ),
        ),
        SliverList.builder(
          itemCount: _selection.files.length,
          itemBuilder: (context, index) {
            final file = _selection.files[index];
            return ListTile(
              title: Text(file.path.split('/').last),
              subtitle: Text(
                file.path,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                tooltip: 'Редактировать перед импортом',
                onPressed: b.busy || _selection.retrying
                    ? null
                    : () => _selection.prepare(file),
                icon: const Icon(Icons.edit_outlined),
              ),
            );
          },
        ),
        if (_selection.drafts.isNotEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Подготовленные файлы · черновики сохраняются на этом устройстве',
              ),
            ),
          ),
        SliverList.builder(
          itemCount: _selection.drafts.length,
          itemBuilder: (context, index) {
            final draft = _selection.drafts[index];
            return ImportEditor(
              key: ValueKey(draft.id),
              selection: _selection,
              draft: draft,
            );
          },
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Загрузки и операции',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        FutureBuilder(
          future: _jobs,
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return SliverToBoxAdapter(
                child: TextButton(
                  onPressed: _refresh,
                  child: const Text('Повторить загрузку операций'),
                ),
              );
            final items = snapshot.data;
            if (items == null)
              return const SliverToBoxAdapter(child: LinearProgressIndicator());
            if (items.isEmpty)
              return const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Здесь появится прогресс импорта'),
                ),
              );
            return SliverList.builder(
              itemCount: items.length,
              itemBuilder: (context, i) => _job(items[i]),
            );
          },
        ),
      ],
    ),
  );
  Widget _job(jobs.Job job) {
    final state = switch (job.state) {
      jobs.JobState.running => 'Выполняется',
      jobs.JobState.succeeded => 'Обработка завершена',
      jobs.JobState.failed => 'Ошибка',
      jobs.JobState.cancelled => 'Отменено',
      jobs.JobState.interrupted => 'Прервано',
    };
    return ExpansionTile(
      title: Text(state),
      subtitle: Text('${job.completed} из ${job.total}'),
      children: [
        if (job.state == jobs.JobState.running)
          LinearProgressIndicator(
            value: job.total == BigInt.zero
                ? null
                : (job.completed.toDouble() / job.total.toDouble()).clamp(0, 1),
          ),
        if (job.error != null) ListTile(title: Text(job.error!.message)),
        for (final file in job.files)
          ListTile(
            leading: Icon(
              file.error != null
                  ? Icons.error_outline
                  : file.review != null
                  ? Icons.copy_outlined
                  : Icons.audio_file_outlined,
            ),
            title: Text(file.review?.title ?? file.operationId),
            subtitle: Text(
              file.error?.message ??
                  (file.review != null
                      ? 'Возможный дубликат. Требуется решение.'
                      : file.command != null
                      ? commandMessage(file.command!)
                      : 'Ожидаем подтверждения'),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (job.state == jobs.JobState.running)
              TextButton(
                onPressed: b.busy
                    ? null
                    : () => b.action(() async {
                        await jobs.cancel(
                          sessionId: b.sessionId,
                          jobId: job.id,
                        );
                        _refresh();
                      }),
                child: const Text('Отменить'),
              ),
            if (job.state == jobs.JobState.interrupted ||
                job.state == jobs.JobState.failed)
              TextButton(
                onPressed: b.busy
                    ? null
                    : () => b.action(() async {
                        await jobs.resume(
                          sessionId: b.sessionId,
                          jobId: job.id,
                        );
                        _refresh();
                      }),
                child: const Text('Продолжить'),
              ),
          ],
        ),
      ],
    );
  }
}
