import 'package:flutter/material.dart';

class ProgressColorHelper {
  static Color getProgressColor(String categoryName, double progress) {
    if (progress > 1) return Colors.red; // Ylitys aina punainen
    switch (categoryName) {
      case "Asuminen":
        return Colors.green;
      case "Liikkuminen":
        return Colors.blue;
      case "Kodin kulut":
        return Colors.orange;
      case "Viihde":
        return Colors.pink;
      case "Harrastukset":
        return Colors.cyan;
      case "Ruoka":
        return Colors.purple;
      case "Terveys":
        return Colors.redAccent;
      case "Hygienia":
        return Colors.teal;
      case "Lemmikit":
        return Colors.brown;
      case "Sijoittaminen":
        return Colors.lightGreen;
      case "Velat":
        return Colors.black;
      default:
        return Colors.grey; // "Muut"-kategoria
    }
  }
}