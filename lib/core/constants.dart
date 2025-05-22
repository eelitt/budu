class Constants {
static const int maxCategories = 25;

  /// Maksimimäärä alakategorioita per yläkategoria budjetissa.
  static const int maxSubcategories = 20;

  /// Maksimipituus kategorian tai alakategorian nimelle merkkeinä.
 static const int maxCategoryNameLength = 20;
  
static const Map<String, List<String>> categoryMapping = {
  "Asuminen": [
    "Vuokra",
    "Asuntolaina",
    "Kiinteistövero",
    "Jätehuolto",
    "Yhtiövastike",
  ],
  "Liikkuminen": [
    "Auton rahoitus",
    "Autopaikan vuokra",
    "Polttoaine",
    "auton verot",
    "Auton ylläpito",
    "Julkiset", 
  ],
  "Laskut ja palvelut": [
    "Sähkö",
    "Puhelinlasku",
    "Nettiliittymä",
    "Vesi",
  ],
  "Vakuutukset": [ 
    "Kotivakuutus", 
    "Autovakuutus", 
    "Henkilövakuutus",
    "Matkavakuutus",
    "Lemmikkivakuutus",
  ],
  "Viihde": [
    "Viihdekulut",
    "Suoratoistopalvelut",
    "Elokuvat ja teatteri",
    "Pelit",
    "Kirjat ja lehdet",
    "Konsertit",
    "Tapahtumat",
  ],
  "Harrastukset": [
    "Harrastuskulut",
    "Urheiluvälineet",
    "Jäsenmaksut",
    "Tapahtumat",
    "Tarvikkeet",
  ],
  "Ruoka": [
    "Ruokakauppa",
    "Ravintolat",
    "Kahvilat",
    "Takeaway",
  ],
  "Terveys": [
    "Terveyskulut",
    "Lääkärikäynnit",
    "Lääkkeet",
    "Terapia",
    "Hammaslääkäri",
    "Silmälääkäri",
  ],
  "Hygienia": [
    "Hygieniakulut",
    "Kosmetiikka",
    "Siivous",
  ],
  "Lemmikit": [
    "Lemmikkikulut",
    "Ruoka",
    "Lääkärikäynnit",
    "Tarvikkeet",
    "Hoito",
  ],
 "Sijoittaminen ja säästäminen": [
    "Säästäminen",
    "Sijoittaminen",
    "Hätärahasto",
    "Osakkeet",
    "Rahastot",
    "Kryptovaluutat"
  ],
  "Velat": [
    "Velat",
    "Luottokortti",
    "Lainat",
    "Korot",
    "Opintolaina",
    "Asuntolainan korot",
    "osa-maksut",
  ],
};

}