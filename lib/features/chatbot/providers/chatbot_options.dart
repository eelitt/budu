class ChatbotOptions {
  final List<String> questions;
  final int step;

  ChatbotOptions({
    required this.questions,
    required this.step,
  });

  List<String> getOptionsForStep() {
    if (step < questions.length) {
      if (questions[step] == "Maksatko muita kuukausittaisia velkoja autorahoituksen lisäksi?" ||
          questions[step] == "Maksatko kuukausittain velkoja, esimerkiksi osamaksuja?" ||
          questions[step] == "Maksatko kuukausittain muita velkoja, esimerkiksi osamaksuja, kuin omakotitalovelkaa?") {
        return ["Kyllä", "Ei"];
      }
      switch (questions[step]) {
        case "Asutko vuokralla, omakotitalossa vai ilman asuntokuluja?":
          return ["Vuokralla", "Omakotitalossa", "Ilman asuntokuluja"];
        case "Onko sinulla autoa?":
          return ["Kyllä", "Ei"];
        case "Onko autosi oma vai maksatko siitä rahoitusta?":
          return ["Oma", "Rahoitettu"];
        case "Onko sinulla kuukausimaksullisia palveluita, esimerkiksi Netflix tai Spotify?":
          return ["Kyllä", "Ei"];
        case "Onko muita säännöllisiä menoja?":
          return ["Kyllä", "Ei"];
        case "Vuokraatko autopaikkaa, esimerkiksi pihapaikkaa tai autotallia?":
          return ["Kyllä", "Ei"];
        case "Onko sinulla renkaiden vaihto- ja säilytyspalvelua?":
          return ["Kyllä", "Ei"];
        case "Haluatko syöttää auton huolto- ja korjauskulut itse vai käyttää suomalaisten keskimääräisiä kuluja?":
          return ["Lisää summa", "Käytä suomalaisten keskim. huolto- ja korjauskustannuksia (1070 € vuodessa)"];
        case "Onko sinulla lemmikkejä?":
          return ["Kyllä", "Ei"];
      }
    }
    return [];
  }
}