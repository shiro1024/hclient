import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/service/gallery_sync/upload_speed.dart';

void main() {
  testWidgets('aggregate request deltas, retries, idle ticks and cleanup', (
    tester,
  ) async {
    final start = tester.binding.clock.now();
    final speed = UploadSpeed(
      elapsed: () => tester.binding.clock.now().difference(start),
    );
    expect(speed.listenable.value, isNull);
    await tester.pump(const Duration(seconds: 2));
    expect(speed.listenable.value, isNull);

    final first = speed.requestProgress();
    final second = speed.requestProgress();
    first(100, 1000);
    first(250, 1000);
    second(400, 1000);
    await tester.pump(const Duration(seconds: 1));
    expect(speed.listenable.value, '650 B/s');
    speed.requestProgress()(80, 1000);
    await tester.pump(const Duration(seconds: 1));
    expect(speed.listenable.value, '80 B/s');
    await tester.pump(const Duration(seconds: 1));
    expect(speed.listenable.value, '0 B/s');

    speed.dispose();
    var lateUpdates = 0;
    void lateListener() => lateUpdates++;
    speed.listenable.addListener(lateListener);
    first(900, 1000);
    await tester.pump(const Duration(seconds: 2));
    expect(speed.listenable.value, isNull);
    expect(lateUpdates, 0);
    speed.listenable.removeListener(lateListener);
  });
}
