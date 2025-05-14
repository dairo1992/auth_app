import 'package:flutter/material.dart';

ThemeData customTheme = ThemeData(
  primarySwatch: Colors.blue,
  brightness: Brightness.light,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF6200EE),
    primary: const Color(0xFF6200EE),
    secondary: const Color(0xFF03DAC6),
  ),
  fontFamily: 'Poppins',
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.grey.shade100,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: const Color(0xFF6200EE), width: 2),
    ),
  ),
);
