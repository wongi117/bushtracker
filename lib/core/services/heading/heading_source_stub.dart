import 'dart:async';

import 'heading_reading.dart';
import 'heading_source.dart';

HeadingSource makeHeadingSource() => NullHeadingSource();

/// Platforms with neither sensors_plus nor a browser (unit tests, desktop
/// builds without sensor plugins). Reports "no compass" rather than pretending
/// to point north.
class NullHeadingSource implements HeadingSource {
  final StreamController<HeadingReading> _controller =
      StreamController<HeadingReading>.broadcast();

  @override
  Stream<HeadingReading> get readings => _controller.stream;

  @override
  void start() {
    if (!_controller.isClosed) {
      _controller.add(const HeadingReading.unavailable());
    }
  }

  @override
  Future<bool> requestPermission() async => false;

  @override
  void dispose() => _controller.close();
}
