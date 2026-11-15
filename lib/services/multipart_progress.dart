import 'dart:async';

import 'package:http/http.dart' as http;

/// A [http.MultipartRequest] that reports how many body bytes have been
/// handed to the HTTP client and can be aborted through [abortTrigger].
class ProgressMultipartRequest extends http.MultipartRequest
    with http.Abortable {
  ProgressMultipartRequest(
    super.method,
    super.url, {
    this.onProgress,
    this.abortTrigger,
  });

  final void Function(int sent, int total)? onProgress;

  /// Completing this future aborts the request (on clients that support it).
  @override
  final Future<void>? abortTrigger;

  @override
  http.ByteStream finalize() {
    final stream = super.finalize();
    final callback = onProgress;
    if (callback == null) return stream;

    final total = contentLength;
    var sent = 0;
    final transformed = stream.transform(
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: (data, sink) {
          sent += data.length;
          sink.add(data);
          if (total > 0) callback(sent > total ? total : sent, total);
        },
      ),
    );
    return http.ByteStream(transformed);
  }
}
