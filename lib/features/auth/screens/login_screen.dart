import 'package:budu/core/app_router.dart';
import 'package:budu/core/utils.dart';
import 'package:budu/features/update/dialogs/update_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // Lisätään Connectivity Plus
import 'package:shared_preferences/shared_preferences.dart'; // Lisätään SharedPreferences
import '../providers/auth_provider.dart';
import '../../budget/providers/budget_provider.dart';
import '../../update/providers/update_provider.dart';
import '../../update/services/update_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final UpdateService _updateService = UpdateService();
  bool _isUpdateRequired = false;
  String? _apkUrl;
  String? _latestVersion;
  double _downloadProgress = 0.0;
  bool _isDownloading = false;
  bool _isLoggingIn = false;

  @override
  void initState() {
    super.initState();
    _checkForAppUpdate(); // Tarkistetaan päivitykset käynnistyksessä
  }

  Future<bool> _checkInstallPermission() async {
    final status = await Permission.requestInstallPackages.status;
    if (!status.isGranted) {
      final result = await Permission.requestInstallPackages.request();
      return result.isGranted;
    }
    return true;
  }

  Future<bool> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<void> _checkForAppUpdate() async {
    final updateProvider = Provider.of<UpdateProvider>(context, listen: false);
    await updateProvider.checkForUpdate(context);

    if (updateProvider.isUpdateAvailable && updateProvider.apkUrl != null) {
      setState(() {
        _isUpdateRequired = true;
        _apkUrl = updateProvider.apkUrl;
        _latestVersion = updateProvider.latestVersion;
      });

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // Tarkistetaan asennusoikeudet
      final hasInstallPermission = await _checkInstallPermission();
      if (!hasInstallPermission) {
        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) {
              return AlertDialog(
                title: const Text('Asennusoikeudet vaaditaan'),
                content: const Text('Sinun on sallittava asennus tuntemattomista lähteistä päivityksen asentamiseksi.'),
                actions: [
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await openAppSettings();
                      // Tarkistetaan oikeudet uudelleen
                      final newStatus = await _checkInstallPermission();
                      if (newStatus) {
                        // Jatketaan päivitysdialogiin, jos oikeudet saatiin
                        _showUpdateDialog(currentVersion);
                      }
                    },
                    child: const Text('Avaa asetukset'),
                  ),
                ],
              );
            },
          );
        }
        return;
      }

      // Tarkistetaan verkkoyhteys
      final hasConnectivity = await _checkConnectivity();
      if (!hasConnectivity) {
        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) {
              return AlertDialog(
                title: const Text('Ei verkkoyhteyttä'),
                content: const Text('Päivityksen lataaminen vaatii internet-yhteyden. Tarkista yhteys ja yritä uudelleen.'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _checkForAppUpdate(); // Yritä uudelleen
                    },
                    child: const Text('Yritä uudelleen'),
                  ),
                ],
              );
            },
          );
        }
        return;
      }

      // Näytetään päivitysdialogi, jos oikeudet ja yhteys ovat kunnossa
      _showUpdateDialog(currentVersion);
    }
  }

  void _showUpdateDialog(String currentVersion) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return UpdateDialog(
          updateService: _updateService,
          currentVersion: currentVersion,
          latestVersion: _latestVersion!,
          apkUrl: _apkUrl!,
          onUpdate: (apkUrl, latestVersion) async {
            await _startDownload(apkUrl, latestVersion);
          },
        );
      },
    );
  }

  Future<void> _startDownload(String apkUrl, String latestVersion) async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    // Näytetään latausdialogi tässä kontekstissa
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Ladataan päivitystä...", style: TextStyle(color: Colors.white)),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(value: _downloadProgress / 100),
                  const SizedBox(height: 8),
                  Text('${_downloadProgress.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white)),
                ],
              ),
              backgroundColor: Colors.black87,
            );
          },
        );
      },
    );

    try {
      await for (var event in _updateService.downloadAndOpenApk(apkUrl, latestVersion)) {
        if (event.containsKey('progress')) {
          setState(() {
            _downloadProgress = event['progress'] as double;
          });
        } else if (event.containsKey('result')) {
          final result = event['result'] as OpenResult;

          if (result.type != ResultType.done) {
            if (result.message.contains("REQUEST_INSTALL_PACKAGES")) {
              // Kysytään lupaa asentaa tuntemattomista lähteistä
              await _requestInstallPermission(apkUrl, latestVersion);
            } else {
              throw Exception('APK:n avaaminen epäonnistui: ${result.message}');
            }
          } else {
            // Päivitys onnistui, tallennetaan tieto SharedPreferencesiin
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('isUpdated', true);
            await prefs.setString('updatedVersion', latestVersion);
            setState(() {
              _isUpdateRequired = false; // Päivitys onnistui, sallitaan sisäänkirjautuminen
            });
          }
        } else if (event.containsKey('error')) {
          throw Exception(event['error'] as String);
        }
      }
    } catch (e) {
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              title: const Text('Päivityksen lataaminen epäonnistui'),
              content: Text('Virhe: $e\nHaluatko yrittää uudelleen?'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _checkForAppUpdate(); // Yritä uudelleen
                  },
                  child: const Text('Kyllä'),
                ),
              ],
            );
          },
        );
      }
    } finally {
      // Suljetaan latausdialogi, jos konteksti on vielä aktiivinen
      if (mounted) {
        Navigator.pop(context);
      }
      setState(() {
        _isDownloading = false;
      });
    }
  }

  Future<void> _requestInstallPermission(String apkUrl, String latestVersion) async {
    // Näytetään dialogi, joka kehottaa sallimaan asennuksen tuntemattomista lähteistä
    if (mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Text('Asennusoikeudet vaaditaan'),
            content: const Text('Sinun on sallittava asennus tuntemattomista lähteistä jatkaaksesi.'),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  // Avaa asetukset, joissa käyttäjä voi sallia asennuksen tuntemattomista lähteistä
                  await openAppSettings();
                  if (mounted) {
                    // Näytetään dialogi, jossa käyttäjä voi yrittää uudelleen
                    await showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text('Yritä uudelleen'),
                          content: const Text('Haluatko yrittää asennusta uudelleen?'),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                // Yritä päivitys uudelleen
                                _startDownload(apkUrl, latestVersion);
                              },
                              child: const Text('Kyllä'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                // Näytetään alkuperäinen päivitysdialogi uudelleen
                                _checkForAppUpdate();
                              },
                              child: const Text('Ei'),
                            ),
                          ],
                        );
                      },
                    );
                  }
                },
                child: const Text('Avaa asetukset'),
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> _navigateAfterLogin() async {
    print('_navigateAfterLogin: Aloitetaan');
    try {
      final authProvider = context.read<AuthProvider>();
      final budgetProvider = context.read<BudgetProvider>();
      if (authProvider.user != null) {
        await Future.delayed(const Duration(seconds: 2));
        print('_navigateAfterLogin: Käyttäjä löytyy: ${authProvider.user!.uid}');
        await budgetProvider.loadBudget(authProvider.user!.uid, DateTime.now().year, DateTime.now().month);
        print('_navigateAfterLogin: Budjetti ladattu, budget == null: ${budgetProvider.budget == null}');
        if (mounted) {
          if (budgetProvider.budget == null) {
            print('_navigateAfterLogin: Budjetti on null, tarkistetaan Firestore');
            final budgetsSnapshot = await FirebaseFirestore.instance
                .collection('budgets')
                .doc(authProvider.user!.uid)
                .collection('monthly_budgets')
                .limit(1)
                .get();
            print('_navigateAfterLogin: Budjettidokumenttien määrä: ${budgetsSnapshot.docs.length}');
            if (budgetsSnapshot.docs.isEmpty) {
              print('_navigateAfterLogin: Ei budjetteja, ohjataan chatbot-sivulle');
              Navigator.pushReplacementNamed(context, AppRouter.chatbotRoute);
            } else {
              print('_navigateAfterLogin: Budjetti löytyy, ohjataan pääsivulle');
              Navigator.pushReplacementNamed(context, AppRouter.mainRoute);
            }
          } else {
            print('_navigateAfterLogin: Nykyinen budjetti löytyy, ohjataan pääsivulle');
            Navigator.pushReplacementNamed(context, AppRouter.mainRoute);
          }
        }
      }
    } catch (e) {
      print('_navigateAfterLogin: Virhe navigoinnissa: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const SizedBox.shrink(),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Budu',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sisäänkirjautuminen',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 250,
                child: _isLoggingIn
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Colors.blue,
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: _isUpdateRequired || _isDownloading
                            ? null // Estetään sisäänkirjautuminen, jos päivitys on kesken tai vaaditaan
                            : () async {
                                setState(() {
                                  _isLoggingIn = true; // Näytetään latausindikaattori
                                });
                                try {
                                  print('Aloitetaan Google-kirjautuminen');
                                  await context.read<AuthProvider>().signInWithGoogle();
                                  print('Google-kirjautuminen onnistui, kutsutaan _navigateAfterLogin');
                                  await _navigateAfterLogin();
                                } catch (e) {
                                  if (mounted) {
                                    print('Google-kirjautumisvirhe: $e');
                                    showErrorSnackBar(context, 'Google-kirjautuminen epäonnistui: $e');
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(() {
                                      _isLoggingIn = false; // Piilotetaan latausindikaattori
                                    });
                                  }
                                }
                              },
                        icon: const Icon(Icons.g_mobiledata),
                        label: const Text('Kirjaudu Googlella'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          textStyle: const TextStyle(fontSize: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}