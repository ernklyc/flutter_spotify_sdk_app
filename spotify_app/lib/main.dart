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
  }

  void _showSuccess(String message) {
    // Boş bırak veya tamamen kaldır
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Icon(
              _connected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
              color: _connected ? const Color(0xFF1DB954) : Colors.grey[600],
              size: 24,
            ),
          ),
        ],
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
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
                          if (!snapshot.hasData ||
                              snapshot.data?.track == null) {
                            return const SizedBox.shrink();
                          }

                          final duration = snapshot.data?.track?.duration ?? 0;
                          final position = snapshot.data?.playbackPosition ?? 0;

                          return Column(
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
                                        snapshot.data!.track!.imageUri.raw
                                            .replaceFirst('spotify:image:',
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
                                snapshot.data!.track!.name,
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
                                snapshot.data!.track!.artist.name ?? '',
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
                                snapshot.data!.track!.album.name ?? '',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[500],
                                  letterSpacing: 0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 16),
                              LinearProgressIndicator(
                                value: duration > 0 ? position / duration : 0.0,
                                backgroundColor: Colors.grey[800],
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Color(0xFF1DB954)),
                                minHeight: 3,
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          bottom: MediaQuery.of(context).padding.bottom + 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Medya kontrol butonları
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 30),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSecondaryControlButton(
                    icon: Icons.skip_previous_rounded,
                    onPressed: _connected ? skipPrevious : null,
                  ),
                  const SizedBox(width: 16),
                  _buildPrimaryControlButton(),
                  const SizedBox(width: 16),
                  _buildSecondaryControlButton(
                    icon: Icons.skip_next_rounded,
                    onPressed: _connected ? skipNext : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Haritaya Ekle ve Profile Ekle butonları
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
                      backgroundColor: const Color(0xFF1DB954).withOpacity(0.9),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 4,
                    ),
                    icon: const Icon(
                      Icons.map_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: const Text(
                      "Haritaya Ekle",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _connected
                        ? () {
                            if (kDebugMode) {
                              print("Profile ekle butonuna basıldı");
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DB954).withOpacity(0.9),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 4,
                    ),
                    icon: const Icon(
                      Icons.favorite_border,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: const Text(
                      "Profile Ekle",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Spotify bağlantı butonu
            Container(
              width: double.infinity,
              height: MediaQuery.of(context).size.height * 0.05,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: const Color(0xFF1DB954).withOpacity(0.15),
              ),
              child: InkWell(
                onTap: openAndConnectToSpotify,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _connected
                          ? Icons.check_circle_outline_rounded
                          : Icons.info_outline_rounded,
                      size: 16,
                      color: const Color(0xFF1DB954).withOpacity(0.8),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _connected
                          ? "Spotify'dan Müzik Seç"
                          : "Spotify'ı Başlatın",
                      style: TextStyle(
                        color: const Color(0xFF1DB954).withOpacity(0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryControlButton({
    required IconData icon,
    VoidCallback? onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(50),
        child: Container(
          padding: const EdgeInsets.all(5),
          child: Icon(
            icon,
            size: 32,
            color: _connected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryControlButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _connected
            ? () async {
                try {
                  if (_isPlaying) {
                    await SpotifySdk.pause();
                  } else {
                    await SpotifySdk.resume();
                  }
                  setState(() => _isPlaying = !_isPlaying);
                } catch (e) {
                  debugPrint("Müzik kontrolü hatası: $e");
                }
              }
            : null,
        splashColor: Colors.transparent,
        borderRadius: BorderRadius.circular(5),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1DB954),
                const Color(0xFF1DB954).withOpacity(0.8),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1DB954).withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 35,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
