import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../core/bridge/generated/api.dart' as api;
import '../../core/bridge/generated/api/auth.dart' as auth;
import '../../core/bridge/generated/api/content.dart' as content;
import '../../core/bridge/generated/api/offline.dart' as offline;
import '../../core/state/backend_controller.dart';

// Rust owns the actual downloads. Remember only their IDs so another opening
// of the same track's dialog can attach to the active job.
typedef _JobKey = (String, String, String);

class _Job {
  _Job(this.id);
  final String id;
  Future<offline.Download>? starting;
}

final _activeJobs = Expando<Map<_JobKey, _Job>>();

Future<void> showTrackOffline(
  BuildContext context,
  BackendController backend,
  api.Track track,
) async {
  final session = backend.session?.sessionId;
  if (session == null) return;
  final jobs = _activeJobs[backend] ??= {};
  jobs.removeWhere((key, _) => key.$1 != session);
  Widget panel() => _TrackOfflinePanel(
    backend: backend,
    sessionId: session,
    track: track,
    jobs: jobs,
  );
  if (MediaQuery.sizeOf(context).width < 700) {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => SafeArea(top: false, child: panel()),
    );
  } else {
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(child: SizedBox(width: 440, child: panel())),
    );
  }
}

class _TrackOfflinePanel extends StatefulWidget {
  const _TrackOfflinePanel({
    required this.backend,
    required this.sessionId,
    required this.track,
    required this.jobs,
  });

  final BackendController backend;
  final String sessionId;
  final api.Track track;
  final Map<_JobKey, _Job> jobs;

  @override
  State<_TrackOfflinePanel> createState() => _TrackOfflinePanelState();
}

class _TrackOfflinePanelState extends State<_TrackOfflinePanel> {
  String? _source;
  offline.Download? _status;
  Object? _error;
  bool _busy = true;
  bool _sessionChanged = false;
  bool _cancelRequested = false;
  int _version = 0;
  Timer? _poll;

  bool get _valid =>
      mounted &&
      !_sessionChanged &&
      widget.backend.session?.sessionId == widget.sessionId;
  _JobKey get _key => (widget.sessionId, widget.track.id, _source!);
  bool get _downloading => _status?.state == offline.Availability.downloading;

  @override
  void initState() {
    super.initState();
    widget.backend.addListener(_sessionChangedListener);
    unawaited(_load());
  }

  void _sessionChangedListener() {
    if (_sessionChanged ||
        widget.backend.session?.sessionId == widget.sessionId) {
      return;
    }
    _poll?.cancel();
    _version++;
    setState(() => _sessionChanged = true);
  }

  @override
  void dispose() {
    _poll?.cancel();
    widget.backend.removeListener(_sessionChangedListener);
    super.dispose();
  }

  // Separate operations from BackendController.operate: downloads must not
  // hold its busy flag and prevent transport controls from working.
  Future<T> _operation<T>(Future<T> Function(auth.Operation) call) async {
    if (!_valid) throw StateError('Профиль изменился');
    final op = await auth.Operation.newInstance();
    try {
      if (!_valid) throw StateError('Профиль изменился');
      return await call(op);
    } finally {
      await op.cancel();
    }
  }

  Future<void> _load() async {
    _poll?.cancel();
    final version = ++_version;
    setState(() {
      _busy = true;
      _error = null;
      _status = null;
      _source = null;
    });
    try {
      final detail = await content.track(
        sessionId: widget.sessionId,
        trackId: widget.track.id,
      );
      if (!_valid || version != _version) return;
      final preferred = detail?.preferredSourceId;
      final sources = detail?.sources ?? const <content.Source>[];
      // Match playback's preferred source; use a real alternative only if
      // the preferred source is no longer registered.
      _source = sources.any((source) => source.id == preferred)
          ? preferred
          : sources.firstOrNull?.id;
      if (_source != null) await _readStatus(version);
    } catch (error) {
      if (_valid && version == _version) setState(() => _error = error);
    } finally {
      if (_valid && version == _version) {
        setState(() => _busy = false);
        _schedulePoll();
      }
    }
  }

  Future<offline.Download> _statusFor(String id, _JobKey key) => _operation(
    (op) => offline.status(
      sessionId: key.$1,
      downloadId: id,
      trackId: key.$2,
      sourceId: key.$3,
      operation: op,
    ),
  );

  Future<void> _readStatus(int version) async {
    final key = _key;
    final job = widget.jobs[key];
    if (job?.starting case final Future<offline.Download> pending) {
      try {
        await pending;
      } catch (_) {
        // A failed start can still have a terminal record in Rust.
      }
    }
    if (!_valid || version != _version) return;
    var status = await _statusFor(job?.id ?? await api.newOperationId(), key);
    if (!_valid || version != _version) return;
    if (job != null && status.state != offline.Availability.downloading) {
      if (identical(widget.jobs[key], job)) widget.jobs.remove(key);
      if (status.state == offline.Availability.fullyCached) {
        // Completed job records contain the original pin bit. A new ID asks
        // Rust for live cache state, including subsequent pin/unpin/eviction.
        status = await _statusFor(await api.newOperationId(), key);
      }
    }
    if (!_valid || version != _version) return;
    setState(() {
      _status = status;
      _error = null;
      if (!_downloading) _cancelRequested = false;
    });
  }

  void _schedulePoll() {
    _poll?.cancel();
    if (!_valid || !_downloading || _busy) return;
    _poll = Timer(const Duration(milliseconds: 500), () async {
      final version = _version;
      try {
        await _readStatus(version);
      } catch (error) {
        if (_valid && version == _version) setState(() => _error = error);
      } finally {
        if (_valid && version == _version) _schedulePoll();
      }
    });
  }

  Future<void> _run(Future<void> Function(_JobKey, int) command) async {
    if (!_valid || _busy || _source == null) return;
    _poll?.cancel();
    final version = ++_version;
    final key = _key;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await command(key, version);
    } catch (error) {
      if (_valid && version == _version) setState(() => _error = error);
    } finally {
      if (_valid && version == _version) {
        setState(() => _busy = false);
        _schedulePoll();
      }
    }
  }

  Future<void> _download() => _run((key, version) async {
    if (widget.jobs.containsKey(key)) {
      await _readStatus(version);
      return;
    }
    final id = await api.newOperationId();
    if (!_valid || version != _version) return;
    if (widget.jobs.containsKey(key)) {
      await _readStatus(version);
      return;
    }
    final job = _Job(id);
    widget.jobs[key] = job;
    final pending = _operation(
      (op) => offline.download(
        sessionId: key.$1,
        downloadId: id,
        trackId: key.$2,
        sourceId: key.$3,
        pinned: true,
        operation: op,
      ),
    );
    job.starting = pending;
    try {
      final status = await pending;
      if (_valid && version == _version) {
        setState(() => _status = status);
      }
    } catch (error) {
      job.starting = null;
      // Rust may already have registered the job before an error reached
      // Flutter. Reconcile it before allowing a second download.
      if (_valid && version == _version) {
        await _readStatus(version);
        if (!_downloading) rethrow;
      }
      return;
    } finally {
      job.starting = null;
    }
    await _readStatus(version);
  });

  Future<void> _pin(bool pinned) => _run((key, version) async {
    await _operation(
      (op) => offline.pin(
        sessionId: key.$1,
        trackId: key.$2,
        sourceId: key.$3,
        pinned: pinned,
        operation: op,
      ),
    );
    await _readStatus(version);
  });

  Future<void> _cancel() => _run((key, version) async {
    final job = widget.jobs[key];
    if (job == null) return;
    setState(() => _cancelRequested = true);
    try {
      await _operation(
        (op) => offline.cancel(
          sessionId: key.$1,
          downloadId: job.id,
          operation: op,
        ),
      );
      await _readStatus(version);
    } catch (_) {
      if (_valid && version == _version) {
        setState(() => _cancelRequested = false);
        // Completion can win the race with cancellation. Read the actual
        // result instead of claiming the download was cancelled.
        await _readStatus(version);
        if (_downloading) rethrow;
      }
    }
  });

  String _description(offline.Download status) => switch (status.state) {
    offline.Availability.unavailable => 'Источник недоступен',
    offline.Availability.remoteOnly => 'Не скачано',
    offline.Availability.downloading =>
      _cancelRequested ? 'Отмена загрузки…' : 'Загрузка…',
    offline.Availability.partiallyCached => 'Скачано частично',
    offline.Availability.fullyCached =>
      status.pinned
          ? 'Сохранено для офлайн-доступа'
          : 'В кэше, может быть удалено автоматически',
    offline.Availability.failedRetryable => 'Не удалось скачать',
    offline.Availability.failedPermanent => 'Источник не удалось скачать',
    offline.Availability.cancelled => 'Загрузка отменена',
  };

  String _bytes(BigInt value) {
    final bytes = value.toDouble();
    return bytes >= 1048576
        ? '${(bytes / 1048576).toStringAsFixed(1)} МБ'
        : '${(bytes / 1024).toStringAsFixed(1)} КБ';
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final total = status?.totalBytes;
    final progress = total != null && total > BigInt.zero
        ? (status!.bytesDownloaded.toDouble() / total.toDouble()).clamp(
            0.0,
            1.0,
          )
        : null;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Офлайн-доступ', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            widget.track.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          if (_sessionChanged)
            const Text('Активный профиль изменился. Откройте трек заново.')
          else ...[
            if (_busy && status == null) const LinearProgressIndicator(),
            if (status != null) ...[
              Text(_description(status)),
              if (_downloading ||
                  status.state == offline.Availability.partiallyCached) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 8),
                Text(
                  '${_bytes(status.bytesDownloaded)}${total == null ? '' : ' / ${_bytes(total)}'}',
                ),
              ],
              const SizedBox(height: 16),
              if (_downloading) ...[
                TextButton.icon(
                  onPressed:
                      _busy ||
                          _cancelRequested ||
                          !widget.jobs.containsKey(_key)
                      ? null
                      : _cancel,
                  icon: const Icon(Icons.close),
                  label: const Text('Отменить загрузку'),
                ),
                const Text('Можно закрыть окно: загрузка продолжится в фоне.'),
              ] else if (status.state == offline.Availability.fullyCached) ...[
                FilledButton.icon(
                  onPressed: _busy ? null : () => _pin(!status.pinned),
                  icon: Icon(
                    status.pinned
                        ? Icons.download_done
                        : Icons.push_pin_outlined,
                  ),
                  label: Text(
                    status.pinned
                        ? 'Убрать из офлайн-доступа'
                        : 'Сохранить для офлайн-доступа',
                  ),
                ),
                if (status.pinned)
                  const Text(
                    'После снятия закрепления файл останется в кэше до очистки.',
                  ),
              ] else if (status.state != offline.Availability.unavailable &&
                  status.state != offline.Availability.failedPermanent)
                FilledButton.icon(
                  onPressed: _busy ? null : _download,
                  icon: const Icon(Icons.download),
                  label: Text(
                    status.state == offline.Availability.remoteOnly
                        ? 'Скачать'
                        : 'Продолжить загрузку',
                  ),
                ),
            ] else if (!_busy && _error == null)
              const Text('Для этой композиции нет доступного источника аудио.'),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text('Не удалось обновить офлайн-доступ: $_error'),
              TextButton(
                onPressed: _busy ? null : _load,
                child: const Text('Обновить состояние'),
              ),
            ],
            if (_busy && status != null) const LinearProgressIndicator(),
          ],
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }
}
