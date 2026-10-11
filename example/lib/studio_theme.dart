import 'package:flutter/material.dart';

const studioInk = Color(0xFF252923);
const studioMuted = Color(0xFF74786F);
const studioPaper = Color(0xFFF5F4EF);
const studioLine = Color(0xFFE3E5DC);
const studioAccent = Color(0xFF526943);

ThemeData studioTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: studioPaper,
  colorScheme: ColorScheme.fromSeed(
    seedColor: studioAccent,
    surface: studioPaper,
    primary: studioAccent,
  ),
  fontFamily: 'sans-serif',
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: studioInk, fontSize: 13),
    bodySmall: TextStyle(color: studioMuted, fontSize: 11),
  ),
  dividerColor: studioLine,
  sliderTheme: const SliderThemeData(
    trackHeight: 3,
    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
    overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    isDense: true,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: studioLine),
      borderRadius: BorderRadius.circular(12),
    ),
  ),
);

class StudioLabel extends StatelessWidget {
  const StudioLabel(this.text, {super.key, this.color = studioMuted});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: color,
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.8,
    ),
  );
}
