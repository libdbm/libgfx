import '../clipping/clip_region.dart';
import '../paths/path.dart';
import 'graphics_state_base.dart';

/// Manages clipping state
class ClipState extends GraphicsStateBase<ClipState> {
  Path? _clipPath;
  ClipRegion? _clipRegion;

  ClipState({Path? clipPath, ClipRegion? clipRegion})
    : _clipPath = clipPath,
      _clipRegion = clipRegion;

  Path? get clipPath => _clipPath;
  ClipRegion? get clipRegion => _clipRegion;

  void setClipPath(Path path) {
    _clipPath = path.clone();
  }

  void setClipRegion(ClipRegion region) {
    _clipRegion = region;
  }

  void intersectClipRegion(ClipRegion region) {
    if (_clipRegion != null) {
      _clipRegion = _clipRegion!.intersect(region);
    } else {
      _clipRegion = region;
    }
  }

  void clearClip() {
    _clipPath = null;
    _clipRegion = null;
  }

  bool hasClip() {
    return _clipPath != null || _clipRegion != null;
  }

  @override
  ClipState clone() {
    return ClipState(clipPath: _clipPath?.clone(), clipRegion: _clipRegion);
  }
}
