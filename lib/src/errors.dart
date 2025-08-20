/// Custom exception hierarchy for libgfx library
library libgfx.errors;

/// Base class for all libgfx exceptions
abstract class LibgfxException implements Exception {
  final String message;
  final Object? cause;

  const LibgfxException(this.message, [this.cause]);

  @override
  String toString() =>
      '$runtimeType: $message${cause != null ? ' (caused by: $cause)' : ''}';
}

/// Thrown when a graphics operation fails
class GraphicsException extends LibgfxException {
  const GraphicsException(String message, [Object? cause])
    : super(message, cause);
}

/// Thrown when a rendering operation fails
class RenderException extends GraphicsException {
  const RenderException(String message, [Object? cause])
    : super(message, cause);
}

/// Thrown when required resources are not available
class ResourceException extends LibgfxException {
  const ResourceException(String message, [Object? cause])
    : super(message, cause);
}

/// Thrown when a font operation fails
class FontException extends ResourceException {
  const FontException(String message, [Object? cause]) : super(message, cause);
}

/// Thrown when an image operation fails
class ImageException extends ResourceException {
  const ImageException(String message, [Object? cause]) : super(message, cause);
}

/// Thrown when an unsupported format is encountered
class UnsupportedFormatException extends LibgfxException {
  final String format;

  const UnsupportedFormatException(this.format, [String? message])
    : super(message ?? 'Unsupported format: $format');
}

/// Thrown when invalid configuration is provided
class ConfigurationException extends LibgfxException {
  const ConfigurationException(String message, [Object? cause])
    : super(message, cause);
}

/// Thrown when an operation would exceed resource limits
class ResourceLimitException extends LibgfxException {
  const ResourceLimitException(String message, [Object? cause])
    : super(message, cause);
}
