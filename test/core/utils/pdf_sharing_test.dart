import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/utils/markdown_pdf_export.dart';

void main() {
  test(
    'PDF sharing generates a document without filesystem or path-provider calls',
    () async {
      final bytes = await MarkdownPdfExporter.render(
        markdown:
            '# Trading note\n\nA useful note with **formatting**.\n\n- First point\n- Second point',
        title: 'Shared note',
      );
      expect(bytes, isNotNull);
      expect(ascii.decode(bytes!.take(5).toList()), '%PDF-');
      expect(
        ascii.decode(
          bytes.skip(bytes.length - 20).toList(),
          allowInvalid: true,
        ),
        contains('%%EOF'),
      );
    },
  );
}
