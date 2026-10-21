import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Triggers a browser download for [content] without exposing tokens in URLs.
Future<bool> downloadTextFile(String filename, String content, {String mime = 'text/csv'}) async {
  final blob = web.Blob([content.toJS].toJS, web.BlobPropertyBag(type: '$mime;charset=utf-8'));
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..style.display = 'none';
  web.document.body?.append(a);
  a.click();
  a.remove();
  web.URL.revokeObjectURL(url);
  return true;
}
