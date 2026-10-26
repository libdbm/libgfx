import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// Markdown files whose ```dart blocks must compile against the current API.
const documents = [
  'README.md',
  'doc/getting-started.md',
  'doc/advanced-features.md',
  'doc/examples.md',
  'doc/api-reference.md',
];

/// Placed on the line before a ```dart block that is not meant to compile,
/// such as an API signature listing.
const marker = '<!-- snippet: skip -->';

/// Declarations available to fragments that are not complete programs.
const prelude = '''
// ignore_for_file: unused_import, unused_local_variable
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:libgfx/libgfx.dart';

final engine = GraphicsEngine(400, 300);

Future<void> snippet() async {
''';

/// A ```dart block extracted from a markdown document.
class Snippet {
  final String document;

  /// 1-based line of the first code line in [document].
  final int line;
  final List<String> code;

  Snippet(this.document, this.line, this.code);

  bool get program => code.any(
    (text) =>
        text.startsWith('void main(') || text.startsWith('Future<void> main('),
  );

  /// Source to analyze, and the number of lines added before [code].
  ///
  /// A fragment's imports move above the prelude; each leaves a blank line
  /// behind so the remaining lines keep their positions.
  (String, int) get source {
    if (program) return (code.join('\n'), 0);
    final imports = code.where((text) => text.startsWith('import ')).toList();
    final body = [
      for (final text in code) text.startsWith('import ') ? '' : text,
    ];
    final header = imports.map((text) => '$text\n').join();
    return (
      '$header$prelude${body.join('\n')}\n}\n',
      imports.length + prelude.split('\n').length - 1,
    );
  }
}

List<Snippet> extract(final String document) {
  final lines = File(document).readAsLinesSync();
  final snippets = <Snippet>[];
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].trim() != '```dart') continue;
    final skip = i > 0 && lines[i - 1].trim() == marker;
    final start = i + 1;
    var end = start;
    while (end < lines.length && lines[end].trim() != '```') {
      end++;
    }
    if (!skip) {
      snippets.add(Snippet(document, start + 1, lines.sublist(start, end)));
    }
    i = end;
  }
  return snippets;
}

void main() {
  group('Documentation snippets compile', () {
    final snippets = [for (final document in documents) ...extract(document)];
    final errors = <String, List<String>>{};
    late Directory scratch;

    setUpAll(() {
      scratch = Directory.systemTemp.createTempSync('doc_snippets');
      final root = Directory.current.uri;
      File('${scratch.path}/.dart_tool/package_config.json')
        ..createSync(recursive: true)
        ..writeAsStringSync(
          jsonEncode({
            'configVersion': 2,
            'packages': [
              {
                'name': 'libgfx',
                'rootUri': root.toString(),
                'packageUri': 'lib/',
                'languageVersion': '3.8',
              },
            ],
          }),
        );
      final offsets = <String, (Snippet, int)>{};
      for (var i = 0; i < snippets.length; i++) {
        final (source, offset) = snippets[i].source;
        final file = File('${scratch.path}/snippet_$i.dart')
          ..writeAsStringSync(source);
        offsets[file.uri.pathSegments.last] = (snippets[i], offset);
      }

      final result = Process.runSync('dart', [
        'analyze',
        '--format=machine',
        scratch.path,
      ]);
      final output = '${result.stdout}\n${result.stderr}';
      for (final entry in const LineSplitter().convert(output)) {
        final fields = entry.split('|');
        if (fields.length < 8 || fields[0] != 'ERROR') continue;
        final name = fields[3].split(Platform.pathSeparator).last;
        final located = offsets[name];
        if (located == null) continue;
        final (snippet, offset) = located;
        final line = snippet.line + int.parse(fields[4]) - 1 - offset;
        (errors[snippet.document] ??= []).add(
          '${snippet.document}:$line: ${fields[7]}',
        );
      }
    });

    tearDownAll(() => scratch.deleteSync(recursive: true));

    for (final document in documents) {
      test(document, () {
        final found = errors[document] ?? const [];
        expect(found, isEmpty, reason: found.join('\n'));
      });
    }
  });
}
