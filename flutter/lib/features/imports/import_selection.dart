import 'package:flutter/foundation.dart';

import '../../core/bridge/generated/api.dart' as api;
import '../../core/bridge/generated/api/jobs.dart' as jobs;
import '../../core/state/backend_controller.dart';

/// Unsubmitted UI selection belongs to the session, not the current route.
/// Accepted jobs and their progress remain authoritative in Rust.
class ImportSelection extends ChangeNotifier {
  ImportSelection(this.backend) : sessionId = backend.sessionId;
  final BackendController backend;
  final String sessionId;
  List<jobs.ImportFile> _files = [];
  String? _jobId;
  bool _disposed = false;
  List<jobs.ImportFile> get files => List.unmodifiable(_files);
  bool get retrying => _jobId != null;

  Future<void> select(List<String> paths) => backend.action(() async {
    if (_disposed || _files.isNotEmpty) return;
    final files = <jobs.ImportFile>[];
    for (final path in paths) {
      files.add(
        jobs.ImportFile(
          path: path,
          trackId: await api.newOperationId(),
          sourceId: await api.newOperationId(),
          operationId: await api.newOperationId(),
          allowDuplicate: false,
        ),
      );
      if (_disposed) return;
    }
    _files = files;
    notifyListeners();
  });

  void clear() {
    if (_disposed || backend.busy || retrying) return;
    _files = [];
    notifyListeners();
  }

  Future<void> send() => backend.action(() async {
    while (!_disposed && _files.isNotEmpty) {
      final batch = _files.take(1000).toList();
      _jobId ??= await api.newOperationId();
      if (_disposed) return;
      // Keep the same job and file IDs after an uncertain response. Navigation
      // does not abandon later batches or accidentally submit a second job.
      await jobs.importFiles(
        sessionId: sessionId,
        jobId: _jobId!,
        files: batch,
      );
      if (_disposed) return;
      _files = _files.sublist(batch.length);
      _jobId = null;
      notifyListeners();
      backend.jobRevision.value++;
    }
  });

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
