/// Artwork-space proportions. The PNG viewBoxes stay intact; clipping only
/// exposes their declared process layers. All logical sizes come from TS.
abstract final class YikeGeometry {
  static const statusMaximumWidth = 420.0;
  static const statusPillWidth = 88.0;
  static const lapPanelWidth = 1.0;
  static const lapBounce = .12;
  static const lapArc = 2.0;
  static const mechanicalOuter = 112 / 300;
  static const mechanicalInner = 78 / 300;
  static const mechanicalPointer = 122 / 300;
  static const waterInset = 1 / 236;
  static const waterTopRadius = 28 / 236;
  static const waterBottomRadius = 118 / 236;
  static const waterReadoutY = .46;
  static const waterReadoutWidth = .84;
  static const sundialCenterY = 158 / 404;
  static const sundialRadius = .47;
  static const sundialReadoutTop = 288 / 316;
  static const sundialShadowInset = 10 / 316;
  static const sundialShadowScale = 296 / 316;
  static const readoutWidth = .72;
}
