import 'package:flutter/material.dart';

/// What the locate button is doing.
///
/// A deliberate cycle rather than a toggle, because there are three useful
/// answers to "where am I" and one button for all of them: take me there once,
/// keep me there, and turn the map so the way I am going is up.
enum LocateMode {
  /// Not following. The map stays where it was put.
  off,

  /// Jumped to the current position once. Panning away is expected and does
  /// not need undoing.
  centred,

  /// Keeps the position centred as it moves, north up.
  follow,

  /// Keeps it centred and turns the map so the direction of travel is up.
  headingUp;

  /// Whether the map should be pulled back to the user on every new fix.
  bool get isFollowing => this == LocateMode.follow || this == LocateMode.headingUp;

  /// Whether the map should be rotated to the direction of travel.
  bool get rotatesMap => this == LocateMode.headingUp;

  /// The next mode when the button is tapped.
  ///
  /// off → centred → follow → headingUp → follow
  ///
  /// It settles between the last two rather than returning to off, because once
  /// you have asked to be followed, the next thing you want is north-up or
  /// heading-up — not to stop being followed. Letting go is what the pan
  /// gesture is for, which is the natural way to say it: you reach for the map.
  LocateMode get next => switch (this) {
        LocateMode.off => LocateMode.centred,
        LocateMode.centred => LocateMode.follow,
        LocateMode.follow => LocateMode.headingUp,
        LocateMode.headingUp => LocateMode.follow,
      };

  /// What a drag on the map turns this into.
  ///
  /// Dragging while being followed means "stop pulling me back". It drops to
  /// [centred] rather than [off] so the next tap goes straight to follow
  /// instead of making you tap twice to get back where you were.
  LocateMode get afterPan => isFollowing ? LocateMode.centred : this;

  IconData get icon => switch (this) {
        LocateMode.off => Icons.my_location_outlined,
        LocateMode.centred => Icons.my_location,
        LocateMode.follow => Icons.gps_fixed,
        LocateMode.headingUp => Icons.navigation,
      };

  /// Said in the snackbar when the mode changes, so the icon does not have to
  /// carry the whole explanation.
  String get label => switch (this) {
        LocateMode.off => 'Not following',
        LocateMode.centred => 'Centred on you',
        LocateMode.follow => 'Following you — north up',
        LocateMode.headingUp => 'Following you — heading up',
      };
}
