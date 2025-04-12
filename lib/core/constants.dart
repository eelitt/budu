const Map<String, List<String>> categoryMapping = {
  "Asuminen": [
    "Vuokra",
    "Vesimaksu",
    "Asuntolaina",
    "Lämmitys",
    "Kiinteistövero",
    "Jätehuolto",
    "Kotivakuutus", // Lyhennetty "KotivakuutusVuokra" ja "KotivakuutusOmakotitalo" -> "Kotivakuutus"
  ],
  "Liikkuminen": [
    "Polttoaine", // "AutoPolttoaine" -> "Polttoaine"
    "Autovakuutus", // "AutoVakuutus" -> "Autovakuutus"
    "Ajoneuvovero",
    "Auton huolto",
    "Auton rahoitus", // "AutoRahoitus" -> "Auton rahoitus"
    "AutopaikanVuokra",
    "Renkaiden vaihto ja säilytys", // "RenkaidenVaihtoJaSäilytys" -> "Renkaiden vaihto ja säilytys"
  ],
  "Palvelut": [
    "Palvelut",
    "Nettiliittymä",
    "Puhelinlasku",
    "Sähkö",
  ],
  "Ruoka": ["Ruoka"],
  "Terveys": ["Terveys"], // Jaetaan "Terveys ja hygienia" kahteen kategoriaan
  "Hygienia": ["Hygienia"],
  "Viihde": ["Viihde"],
  "Lemmikit": ["Lemmikit"],
  "Muut": ["Muut"],
};