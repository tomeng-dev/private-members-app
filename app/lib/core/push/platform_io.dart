import 'dart:io' as io;

String detectPlatform() {
  if (io.Platform.isAndroid) return 'android';
  if (io.Platform.isIOS) return 'ios';
  return 'unknown';
}

bool get isIosPlatform => io.Platform.isIOS;
