import 'package:cv_app/src/pdf/markdown_pdf_renderer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  final renderer = const MarkdownPdfRenderer(
    baseStyle: pw.TextStyle(),
    linkColor: PdfColors.blue,
  );

  String plainText(pw.TextSpan span) {
    final buffer = StringBuffer(span.text ?? '');
    for (final child in span.children ?? const <pw.InlineSpan>[]) {
      buffer.write(plainText(child as pw.TextSpan));
    }
    return buffer.toString();
  }

  test('paragrafo semplice produce un RichText con lo stesso testo', () {
    final blocks = renderer.render('Ciao mondo');
    expect(blocks, hasLength(1));
    final richText = blocks.single as pw.RichText;
    expect(plainText(richText.text as pw.TextSpan), 'Ciao mondo');
  });

  test('righe consecutive senza riga vuota si uniscono con uno spazio', () {
    final blocks = renderer.render('riga uno\nriga due');
    final richText = blocks.single as pw.RichText;
    expect(plainText(richText.text as pw.TextSpan), 'riga uno riga due');
  });

  test('due paragrafi separati da riga vuota producono due blocchi', () {
    final blocks = renderer.render('primo\n\nsecondo');
    expect(blocks, hasLength(3)); // paragrafo, spacer, paragrafo
    expect(blocks[1], isA<pw.SizedBox>());
  });

  test('bold e italic diventano span con font diverso dal base', () {
    final blocks = renderer.render('**bold** e *italic*');
    final span = (blocks.single as pw.RichText).text as pw.TextSpan;
    final children = span.children!;
    expect((children[0] as pw.TextSpan).text, 'bold');
    expect((children[0] as pw.TextSpan).style?.fontWeight, pw.FontWeight.bold);
    final italicSpan = children.firstWhere(
      (c) => (c as pw.TextSpan).text == 'italic',
    ) as pw.TextSpan;
    expect(italicSpan.style?.fontStyle, pw.FontStyle.italic);
  });

  test('un link produce uno span con AnnotationUrl e colore link', () {
    final blocks = renderer.render('vedi [qui](https://example.com)');
    final span = (blocks.single as pw.RichText).text as pw.TextSpan;
    final linkSpan = span.children!.firstWhere(
      (c) => (c as pw.TextSpan).text == 'qui',
    ) as pw.TextSpan;
    expect(linkSpan.annotation, isA<pw.AnnotationUrl>());
    expect(
      (linkSpan.annotation as pw.AnnotationUrl).destination,
      'https://example.com',
    );
    expect(linkSpan.style?.color, PdfColors.blue);
  });

  test('lista puntata produce una Column di righe con marker •', () {
    final blocks = renderer.render('- uno\n- due');
    final column = blocks.single as pw.Column;
    expect(column.children, hasLength(2));
  });

  test('lista numerata mantiene i numeri come marker', () {
    final blocks = renderer.render('1. uno\n2. due');
    final column = blocks.single as pw.Column;
    final firstRow = (column.children.first as pw.Padding).child as pw.Row;
    final markerBox = firstRow.children.first as pw.SizedBox;
    final markerText = markerBox.child as pw.Text;
    expect((markerText.text as pw.TextSpan).text, '1.');
    final secondRow = (column.children[1] as pw.Padding).child as pw.Row;
    final secondMarkerBox = secondRow.children.first as pw.SizedBox;
    final secondMarkerText = secondMarkerBox.child as pw.Text;
    expect((secondMarkerText.text as pw.TextSpan).text, '2.');
  });

  test('markdown vuoto non produce blocchi', () {
    expect(renderer.render(''), isEmpty);
    expect(renderer.render('   \n  '), isEmpty);
  });
}
