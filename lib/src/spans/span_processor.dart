import 'span.dart';

/// A processor for spans in the rendering pipeline
abstract class SpanProcessor {
  List<Span> process(List<Span> spans);
}
