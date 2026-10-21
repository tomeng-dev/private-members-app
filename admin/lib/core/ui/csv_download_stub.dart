/// Non-web fallback: returns false so callers can show the CSV another way.
Future<bool> downloadTextFile(String filename, String content, {String mime = 'text/csv'}) async => false;
