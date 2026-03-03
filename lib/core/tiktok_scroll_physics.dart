import 'package:flutter/material.dart';

/// Custom [PageScrollPhysics] that replicates TikTok's scroll feel.
///
/// Spring tuning:
///   mass = 1     → light, responsive (high mass = swipe carries through pages)
///   stiffness = 100 → snappy return to nearest page
///   damping = 1   → critically damped, no overshoot or oscillation
///
/// DO NOT increase mass above ~2 or the momentum from a normal swipe
/// will carry through multiple pages (the original bug).
class TikTokScrollPhysics extends PageScrollPhysics {
  const TikTokScrollPhysics({super.parent});

  @override
  TikTokScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      TikTokScrollPhysics(parent: buildParent(ancestor));

  @override
  SpringDescription get spring =>
      const SpringDescription(mass: 1, stiffness: 150, damping: 30);
}
