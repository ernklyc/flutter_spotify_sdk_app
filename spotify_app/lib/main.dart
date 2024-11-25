// Gerekli paketleri import ediyoruz
import 'dart:async'; // Asenkron işlemler için Dart paketi
import 'package:flutter/material.dart'; // Flutter UI bileşenleri için
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Çevresel değişkenleri .env dosyasından yüklemek için
import 'package:spotify_sdk/spotify_sdk.dart'; // Spotify SDK'sı ile etkileşim kurmak için
import 'package:flutter/services.dart'; // Platform spesifik hataları yakalamak için
import 'package:url_launcher/url_launcher.dart'; // URL'leri başlatmak ve Spotify uygulamasını açmak için
import 'package:spotify_sdk/models/player_state.dart'; // Spotify çalar durumu modeli

// Uygulamanın giriş noktası (main fonksiyonu)
Future<void> main() async {
  // .env dosyasından çevresel değişkenleri yüklüyoruz
  await dotenv.load(fileName: 'assets/.env');
  runApp(const SpotifyApp()); // Ana uygulamayı başlatıyoruz
}

// Ana uygulama widget'ı
class SpotifyApp extends StatelessWidget {
  const SpotifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: const Color(0xFF1DB954), // Spotify yeşili
        scaffoldBackgroundColor: Colors.black,
        cardColor: const Color(0xFF282828),
      ),
      home: const SpotifyHomePage(),
    );
  }
}

// Spotify uygulamasının ana sayfası (StatefulWidget)
class SpotifyHomePage extends StatefulWidget {
  const SpotifyHomePage({super.key});

  @override
  _SpotifyHomePageState createState() => _SpotifyHomePageState();
}

class _SpotifyHomePageState extends State<SpotifyHomePage> {
  bool _connected = false;
  bool _isPlaying = false;
  StreamSubscription<PlayerState>?
      _playerStateSubscription; // Stream aboneliği için

  @override
  void initState() {
    super.initState();
    checkPlaybackState();
    _initializePlayerState(); // Player state stream'ini başlat
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel(); // Stream aboneliğini iptal et
    super.dispose();
  }

  // Player state stream'ini başlat
  Future<void> _initializePlayerState() async {
    try {
      _playerStateSubscription =
          SpotifySdk.subscribePlayerState().listen((playerState) {
        if (mounted) {
          setState(() {
            _isPlaying = !playerState.isPaused;
          });
        }
      }, onError: (e) {
        print("Player state stream hatası: $e");
      });
    } catch (e) {
      print("Player state stream başlatılamadı: $e");
    }
  }

  // Spotify bağlantı fonksiyonunu güncelle
  Future<void> openAndConnectToSpotify() async {
    try {
      const url = 'spotify://';
      if (await canLaunch(url)) {
        await launch(url);
      } else {
        print("Spotify uygulaması açılamıyor. Yüklü mü?");
        return;
      }

      await Future.delayed(const Duration(seconds: 2));

      bool result = await SpotifySdk.connectToSpotifyRemote(
        clientId: dotenv.env['CLIENT_ID']!,
        redirectUrl: dotenv.env['REDIRECT_URL']!,
      );

      if (result) {
        print("Spotify'a başarılı şekilde bağlanıldı!");
        var playerState = await SpotifySdk.getPlayerState();

        setState(() {
          _connected = true;
          _isPlaying = playerState?.isPaused == false;
        });

        // Bağlantı başarılı olduktan sonra stream'i yeniden başlat
        await _initializePlayerState();
      } else {
        setState(() {
          _connected = false;
        });
        print("Spotify'a bağlanılamadı.");
      }
    } on PlatformException catch (e) {
      print("Bağlantı hatası: ${e.message}");
      setState(() {
        _connected = false;
      });
    }
  }

  // Müzik durumunu kontrol eden fonksiyon
  Future<void> checkPlaybackState() async {
    if (_connected) {
      try {
        var playerState = await SpotifySdk.getPlayerState();
        setState(() {
          _isPlaying = playerState?.isPaused == false;
        });
      } catch (e) {
        print("Müzik durumu alınamadı: $e");
      }
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
                                    print("Müzik kontrolü hatası: $e");
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
                                  print("Haritaya ekle butonuna basıldı");
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
                                  print(
                                      "Sevdiğim şarkılara ekle butonuna basıldı");
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

  /// Sonraki müzik
  Future<void> skipNext() async {
    try {
      // Sonraki şarkıya geç
      await SpotifySdk.skipNext();
    } catch (e) {
      print("Sonraki müziğe geçilemedi: $e");
    }
  }

  /// Önceki müzik
  Future<void> skipPrevious() async {
    try {
      // Önceki şarkıya geç
      await SpotifySdk.skipPrevious();
    } catch (e) {
      print("Önceki müziğe geçilemedi: $e");
    }
  }
}
