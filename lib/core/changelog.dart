import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class Changelog {
  static Future<String?> fetchChanges(String version) async {
    try {
      // Haetaan .env-tiedostosta tarvittavat arvot
      final repoOwner = dotenv.env['GITHUB_OWNER'];
      final repoName = dotenv.env['GITHUB_REPO'];
      final apiToken = dotenv.env['GITHUB_API_TOKEN'];

      if (repoOwner == null || repoOwner.isEmpty || repoName == null || repoName.isEmpty || apiToken == null || apiToken.isEmpty) {
        throw Exception('GitHub-autentikointitiedot puuttuvat .env-tiedostosta');
      }

      // GitHub API:n URL tiedoston hakemiseen
      final url = Uri.parse('https://api.github.com/repos/$repoOwner/$repoName/contents/CHANGELOG.txt');

      // Suoritetaan haku GitHub API:lla
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'token $apiToken',
          'Accept': 'application/vnd.github.v3.raw', // Haetaan raakadata
        },
      );

      if (response.statusCode == 200) {
        final changelogContent = response.body;
        // Etsitään vain kyseisen version muutokset
        final lines = changelogContent.split('\n');
        final versionHeader = '## $version';
        final changelogForVersion = StringBuffer();
        bool isRecording = false;

        for (var line in lines) {
          if (line.trim() == versionHeader) {
            isRecording = true;
            changelogForVersion.writeln(line);
            continue;
          }
          if (isRecording) {
            if (line.trim().startsWith('## ') && line.trim() != versionHeader) {
              break; // Lopetetaan, kun seuraava versio alkaa
            }
            changelogForVersion.writeln(line);
          }
        }

        return changelogForVersion.isNotEmpty ? changelogForVersion.toString() : null;
      } else {
        throw Exception('Päivitystietojen haku epäonnistui: HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Virhe päivitystietojen haussa: $e');
    }
  }
}