class ChatbotOptions {
  final List<String> questions;
  final int step;

  ChatbotOptions({
    required this.questions,
    required this.step,
  });

  List<String> getOptionsForStep() {
    if (step < questions.length) {
      if (questions[step] == "Haluatko luoda kuukausibudjetin vai 2 viikon budjetin?") {
        return ["Kuukausi", "2 viikkoa"];
      }
      if (questions[step] == "Maksatko muita kuukausittaisia velkoja autorahoituksen ja asuntolainan lisäksi?" ||
          questions[step] == "Maksatko asuntolainan lisäksi muita velkoja?" ||
          questions[step] == "Maksatko muita kuukausittaisia velkoja autorahoituksen lisäksi?" ||
          questions[step] == "Onko sinulla velkoja?" ||
          questions[step] == "Vuokraatko autopaikkaa?") {
        return ["Kyllä", "Ei"];
      }
      switch (questions[step]) {
        case "Mikä seuraavista kuvaa parhaiten asumistasi?":
          return [
            "Vuokra-asunto",
            "Omistusasunto kerros-/rivitalossa (esim. yhtiövastiketta maksava)",
            "Omistusasunto omakotitalossa",
            "Asun ilman asuntokuluja (esim. vanhempien luona tai ilmaiseksi)",
          ];
        case "Onko sinulla autoa?":
          return ["Kyllä", "Ei"];
        case "Onko autosi oma vai maksatko siitä rahoitusta?":
          return ["Oma auto", "Rahoitettu"];
        case "Onko sinulla lemmikki/lemmikkejä?":
          return ["Kyllä", "Ei"];
      }
    }
    return [];
  }
}