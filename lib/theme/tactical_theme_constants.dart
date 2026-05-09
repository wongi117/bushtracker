import 'package:flutter/material.dart';

const Color kDarkBg = Color(0xFF121212);
const Color kGlassTint = Color(0x99252525);
const Color kGoldAccent = Color(0xFFFFD700);
const Color kGreenAccent = Color(0xFF00E676);
const Color kPurpleAccent = Color(0xFF9C27B0);
const Color kTextWhite = Colors.white;
const Color kTextGold = kGoldAccent;

const LinearGradient kTacticalGradient = LinearGradient(
  colors: [kGoldAccent, kGreenAccent, kPurpleAccent],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const TextStyle kHeadlineStyle = TextStyle(
  color: kTextGold,
  fontSize: 20,
  fontWeight: FontWeight.bold,
  letterSpacing: 1.1,
);

const TextStyle kBodyTextStyle = TextStyle(
  color: kTextWhite,
  fontSize: 16,
);

const TextStyle kCaptionStyle = TextStyle(
  color: Colors.white70,
  fontSize: 14,
);