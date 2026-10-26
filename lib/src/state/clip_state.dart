import '../clipping/clip_region.dart';
import '../paths/path.dart';
import 'state_base.dart';

/// Manages clipping state
class ClipState extends StateBase<ClipState> {
  Path? _path;
  ClipRegion? _region;

  ClipState({Path? clipPath, ClipRegion? clipRegion})
    : _path = clipPath,
      _region = clipRegion;

  Path? get clipPath => _path;
  ClipRegion? get clipRegion => _region;

  void setClipPath(Path path) {
    _path = path.clone();
  }

  void setClipRegion(ClipRegion region) {
    _region = region;
  }

  void clearClip() {
    _path = null;
    _region = null;
  }

  @override
  ClipState clone() {
    return ClipState(clipPath: _path?.clone(), clipRegion: _region);
  }
}
