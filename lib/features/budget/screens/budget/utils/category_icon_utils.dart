import 'package:flutter/material.dart';

/// Palauttaa sopivan ikonin kategorian nimen perusteella.
/// Yrittää tunnistaa avainsanoja kategorian nimestä, jos nimeä ei löydy kovakoodatuista kategorioista.
IconData getCategoryIcon(String categoryName) {
  // Kovakoodatut kategoriat
  switch (categoryName) {
    case "Asuminen":
      return Icons.home;
    case "Liikkuminen":
      return Icons.directions_car;
    case "Laskut ja palvelut":
      return Icons.receipt_long;
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
    case "Sijoittaminen ja säästäminen":
      return Icons.savings;
    case "Velat":
      return Icons.money_off;
    case "Vakuutukset":
      return Icons.description;
    case "Muut":
      return Icons.category;
    default:
      // Yritä tunnistaa avainsanoja kategorian nimestä
      final nameLower = categoryName.toLowerCase();
      if (nameLower.contains('matkailu') || nameLower.contains('loma')) {
        return Icons.airplanemode_active;
      } else if (nameLower.contains('vaatteet') || nameLower.contains('muoti')) {
        return Icons.checkroom;
      } else if (nameLower.contains('lahjat') || nameLower.contains('juhlat')) {
        return Icons.card_giftcard;
      } else if (nameLower.contains('elektroniikka') || nameLower.contains('laitteet')) {
        return Icons.devices;
      } else if (nameLower.contains('koulutus') || nameLower.contains('opiskelu')) {
        return Icons.school;
      } else if (nameLower.contains('työ') || nameLower.contains('toimisto')) {
        return Icons.work;
      }
      // Oletusikoni, jos sopivaa ei löydy
      return Icons.category;
  }
}