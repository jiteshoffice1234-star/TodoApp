import 'package:flutter/material.dart';

Color parseHexColor(String hex, {Color fallback = const Color(0xFF1976D2)}) {
  try {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  } catch (_) {
    return fallback;
  }
}
