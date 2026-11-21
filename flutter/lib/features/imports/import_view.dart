import 'package:file_selector/file_selector.dart';
import 'package:material_ui/material_ui.dart';
import '../../core/bridge/generated/api/jobs.dart' as jobs;
import '../../core/bridge/generated/api.dart' as api;
import '../../core/state/backend_controller.dart';
import '../library/track_actions.dart';

class ImportView extends StatefulWidget {
  const ImportView({super.key, required this.backend});
  final BackendController backend;
  @override
  State<ImportView> createState() => _ImportViewState();
}

class _ImportViewState extends State<ImportView> {
  late Future<List<jobs.Job>> _jobs;
  bool _selecting = false;
  List<jobs.ImportFile> _pending = [];
  String? _jobId;
  BackendController get b => widget.backend;
  @override
  void initState() {
    super.initState();
    _refresh();
    b.jobRevision.addListener(_refresh);
  }

  @override
  void dispose() {
    b.jobRevision.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
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
      final pending = <jobs.ImportFile>[];
      for (final file in files) {
        pending.add(
          jobs.ImportFile(
            path: file.path,
            trackId: await api.newOperationId(),
            sourceId: await api.newOperationId(),
            operationId: await api.newOperationId(),
            allowDuplicate: false,
          ),
        );
      }
      if (mounted)
        setState(() {
          _pending = pending;
          _jobId = null;
        });
    } catch (e) {
      await b.action(() async {
        throw e;
      });
    } finally {
      if (mounted) setState(() => _selecting = false);
    }
  }

  Future<void> _send() async {
    if (_pending.isEmpty) return;
    await b.action(() async {
      // The backend accepts 1000 per durable job. Every file is retained and
      // submitted in explicit batches; never truncate a user's selection.
      while (_pending.isNotEmpty) {
        final batch = _pending.take(1000).toList();
        _jobId ??= await api.newOperationId();
        await jobs.importFiles(
          sessionId: b.sessionId,
          jobId: _jobId!,
          files: batch,
        );
        if (!mounted) return;
        setState(() {
          _pending = _pending.sublist(batch.length);
          _jobId = null;
        });
        _refresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: b,
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
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Выберите файлы. Загрузка продолжится, пока приложение открыто; состояние операций сохраняет KIYORA.',
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _selecting || b.busy || _pending.isNotEmpty
                      ? null
                      : _pick,
                  icon: const Icon(Icons.audio_file_outlined),
                  label: const Text('Выбрать файлы'),
                ),
                if (_selecting) const LinearProgressIndicator(),
                if (_pending.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('Выбрано файлов: ${_pending.length}'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: b.busy ? null : _send,
                    child: Text(
                      _jobId == null
                          ? 'Отправить как есть'
                          : 'Продолжить отправку',
                    ),
                  ),
                  TextButton(
                    onPressed: b.busy || _jobId != null
                        ? null
                        : () => setState(() => _pending = []),
                    child: const Text('Отменить выбор'),
                  ),
                ],
                const SizedBox(height: 28),
                Text(
                  'Загрузки и операции',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
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
