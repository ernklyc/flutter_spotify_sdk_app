import 'dart:async' show StreamSubscription;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:spotify_sdk/spotify_sdk.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:spotify_sdk/models/player_state.dart';

void main() async {
  await dotenv.load(fileName: 'assets/.env');
  runApp(const SpotifyApp());
}

class SpotifyApp extends StatelessWidget {
  const SpotifyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          primaryColor: const Color(0xFF1DB954),
          scaffoldBackgroundColor: Colors.black,
          cardColor: const Color(0xFF282828),
        ),
        home: const SpotifyHomePage(),
      );
}

class SpotifyHomePage extends StatefulWidget {
  const SpotifyHomePage({super.key});

  @override
  State<SpotifyHomePage> createState() => _SpotifyHomePageState();
}

class _SpotifyHomePageState extends State<SpotifyHomePage> {
  static const spotifyGreen = Color(0xFF1DB954);
  
  bool _connected = false;
  bool _isPlaying = false;
  StreamSubscription<PlayerState>? _playerStateSubscription;

  @override
  void initState() {
    super.initState();
    _initializeSpotify();
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeSpotify() async {
    await _initializePlayerState();
    await _checkConnectionStatus();
  }

  Future<void> _initializePlayerState() async {
    try {
      _playerStateSubscription = SpotifySdk.subscribePlayerState().listen(
        _onPlayerStateChanged,
        onError: (e) => debugPrint('Player state stream hatası: $e'),
      );
    } catch (e) {
      debugPrint('Player state stream başlatılamadı: $e');
    }
  }

  void _onPlayerStateChanged(PlayerState state) {
    if (!mounted) return;
    setState(() {
      _isPlaying = !state.isPaused;
    });
  }

  Future<void> _checkConnectionStatus() async {
    try {
      final playerState = await SpotifySdk.getPlayerState();
      if (mounted) {
        setState(() => _connected = playerState != null);
      }
    } catch (e) {
      debugPrint('Bağlantı durumu kontrol edilemedi: $e');
    }
  }

  Future<void> openAndConnectToSpotify() async {
    try {
      const spotifyUrl = 'spotify://';
      // ignore: deprecated_member_use
      if (!await canLaunch(spotifyUrl)) {
        _showError('Spotify uygulaması yüklü değil');
        return;
      }

      // ignore: deprecated_member_use
      await launch(spotifyUrl);
      await Future.delayed(const Duration(seconds: 2));

      final connected = await SpotifySdk.connectToSpotifyRemote(
        clientId: dotenv.env['CLIENT_ID']!,
        redirectUrl: dotenv.env['REDIRECT_URL']!,
      );

      if (connected) {
        await _initializeSpotify();
        _showSuccess('Spotify\'a bağlanıldı');
      } else {
        _showError('Spotify\'a bağlanılamadı');
      }
    } on PlatformException catch (e) {
      _showError('Bağlantı hatası: ${e.message}');
    }
  }

  void _showError(String message) {
    setState(() => _connected = false);
    _showSnackBar(message, Colors.red);
  }

  void _showSuccess(String message) {
    _showSnackBar(message, spotifyGreen);
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }


  Future<void> skipNext() async {
    try {
      await SpotifySdk.skipNext();
    } catch (e) {
      _showError('Sonraki şarkıya geçilemedi');
    }
  }

  Future<void> skipPrevious() async {
    try {
      await SpotifySdk.skipPrevious();
    } catch (e) {
      _showError('Önceki şarkıya geçilemedi');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.network(
              'https://storage.googleapis.com/pr-newsroom-wp/1/2018/11/Spotify_Logo_RGB_White.png',
              height: 25,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.music_note),
            ),
            const Text(
              "Controll Center",
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 20),
            ),
          ],
        ),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF1DB954).withOpacity(0.5), // Daha belirgin yeşil
              Colors.black.withOpacity(0.8),
              Colors.black,
            ],
            stops: const [0.0, 0.4, 0.8],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 12,
                    color: Colors.black.withOpacity(0.7),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: StreamBuilder<PlayerState>(
                        stream: SpotifySdk.subscribePlayerState(),
                        builder: (context, snapshot) {
                          // Müzik durumunu kontrol et ama doğrudan atama yapma
                          bool isCurrentlyPlaying = snapshot.hasData &&
                              snapshot.data?.isPaused == false;

                          if (!snapshot.hasData ||
                              snapshot.data?.track == null) {
                            return const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.music_off,
                                      size: 48, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text(
                                    "Müzik bilgisi alınamıyor...",
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            );
                          }

                          // Eğer durum değiştiyse, Future.microtask ile güncelle
                          if (_isPlaying != isCurrentlyPlaying) {
                            Future.microtask(() {
                              if (mounted) {
                                setState(() {
                                  _isPlaying = isCurrentlyPlaying;
                                });
                              }
                            });
                          }

                          var track = snapshot.data!.track!;
                          String? imageUrl = track.imageUri.raw;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...[
                                Center(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(15),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 15,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(15),
                                      child: Image.network(
                                        imageUrl.replaceFirst('spotify:image:',
                                            'https://i.scdn.co/image/'),
                                        height: 240,
                                        width: 240,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Container(
                                            height: 240,
                                            width: 240,
                                            color: Colors.grey[900],
                                            child: const Icon(
                                              Icons.music_note,
                                              size: 64,
                                              color: Colors.white54,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ],
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1DB954).withOpacity(
                                      0.2), // Daha belirgin arka plan
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: const Color(0xFF1DB954).withOpacity(
                                        0.4), // Daha belirgin kenar
                                    width: 1,
                                  ),
                                ),
                                child: const Text(
                                  "ŞUAN ÇALIYOR",
                                  style: TextStyle(
                                    color: Color(0xFF1DB954), // Tam yeşil renk
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                track.name,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                track.artist.name ?? '',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[300],
                                  letterSpacing: 0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                track.album.name ?? '',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[500],
                                  letterSpacing: 0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1DB954).withOpacity(0),
                          blurRadius: 20,
                          spreadRadius: -5,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.skip_previous, size: 44),
                          onPressed: _connected ? skipPrevious : null,
                          color: _connected ? Colors.white : Colors.grey[700],
                          splashColor: const Color(0xFF1DB954).withOpacity(1),
                          splashRadius: 30,
                        ),
                        IconButton(
                          icon: Icon(
                            _isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_filled,
                            size: 44,
                          ),
                          onPressed: _connected
                              ? () async {
                                  try {
                                    if (_isPlaying) {
                                      await SpotifySdk.pause();
                                    } else {
                                      await SpotifySdk.resume();
                                    }
                                    setState(() {
                                      _isPlaying = !_isPlaying;
                                    });
                                  } catch (e) {
                                    if (kDebugMode) {
                                      print("Müzik kontrolü hatası: $e");
                                    }
                                  }
                                }
                              : null,
                          color: _connected ? Colors.white : Colors.grey[700],
                          splashColor: const Color(0xFF1DB954).withOpacity(1),
                          splashRadius: 30,
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next, size: 44),
                          onPressed: _connected ? skipNext : null,
                          color: _connected ? Colors.white : Colors.grey[700],
                          splashColor: const Color(0xFF1DB954).withOpacity(1),
                          splashRadius: 30,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // İki butonu yan yana yerleştiriyoruz
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _connected
                              ? () {
                                  if (kDebugMode) {
                                    print("Haritaya ekle butonuna basıldı");
                                  }
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1DB954),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          icon: const Icon(Icons.map_outlined,
                              color: Colors.white),
                          label: const Text(
                            "Haritaya Ekle",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8), // Butonlar arası boşluk
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _connected
                              ? () {
                                  if (kDebugMode) {
                                    print(
                                      "Sevdiğim şarkılara ekle butonuna basıldı");
                                  }
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1DB954),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          icon: const Icon(
                            Icons.favorite_border,
                            color: Colors.white,
                          ),
                          label: const Text(
                            "Favorilere Ekle",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: ElevatedButton.icon(
                      onPressed: openAndConnectToSpotify,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _connected
                            ? const Color(0xFF1DB954)
                            : const Color(0xFFE22134).withOpacity(0.9),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        elevation: 8,
                        shadowColor: _connected
                            ? const Color(0xFF1DB954).withOpacity(0.6)
                            : const Color(0xFFE22134).withOpacity(0.4),
                      ),
                      icon: Icon(
                          _connected ? Icons.check_circle : Icons.music_note),
                      label: Text(
                        _connected
                            ? "Bağlantı Aktif"
                            : "Spotify'a Bağlan ve Müzik Çal",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
