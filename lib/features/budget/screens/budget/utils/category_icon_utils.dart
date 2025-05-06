import 'package:flutter/material.dart';

IconData getCategoryIcon(String categoryName) {
  switch (categoryName) {
    case "Asuminen":
      return Icons.home;
    case "Liikkuminen":
      return Icons.directions_car;
    case "Kodin kulut":
      return Icons.power;
    case "Viihde":
      return Icons.movie;
    case "Harrastukset":
      return Icons.sports;
    case "Ruoka":
      return Icons.fastfood;
    case "Terveys":
      return Icons.local_hospital;
    case "Hygienia":
      return Icons.cleaning_services;
    case "Lemmikit":
      return Icons.pets;
    case "Sijoittaminen":
      return Icons.savings;
    case "Velat":
      return Icons.money_off;
    case "Muut":
      return Icons.category;
    default:
      return Icons.category;
  }
}