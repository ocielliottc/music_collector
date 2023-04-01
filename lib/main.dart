import 'package:flutter/material.dart';
import 'screens/list_albums.dart';

void main() {
  runApp(const MusicCollector());
}

class MusicCollector extends StatelessWidget {
  const MusicCollector({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.yellow.shade600,
      ),
      theme: ThemeData(
        brightness: Brightness.light,
        colorSchemeSeed: Colors.red.shade800,
      ),
      home: const ListAlbums(),
    );
  }
}
