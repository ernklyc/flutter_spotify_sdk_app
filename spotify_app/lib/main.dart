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
  runApp(SpotifyApp()); // Ana uygulamayı başlatıyoruz
}

// Ana uygulama widget'ı
class SpotifyApp extends StatelessWidget {
  const SpotifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Uygulama için MaterialApp widget'ını oluşturuyoruz
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Debug banner'ını kaldırıyoruz
      theme: ThemeData.dark(), // Karanlık tema kullanıyoruz
      home: SpotifyHomePage(), // Ana sayfa olarak SpotifyHomePage'i ayarlıyoruz
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
  bool _connected = false; // Spotify'a bağlı olup olmadığımızı belirten değişken

  @override
  void initState() {
    super.initState();
    // Uygulama başlatıldığında Spotify'a bağlanmayı deneyebilirsiniz
    // openAndConnectToSpotify();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Spotify Kontrol Paneli"), // Uygulamanın başlık çubuğu
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0), // Etrafında boşluk olan bir yapı
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, // Bileşenleri genişlet
          children: [
            // Spotify uygulamasını açmak ve bağlanmak için bir düğme
            ElevatedButton(
              onPressed: openAndConnectToSpotify,
              child: const Text("Spotify'ı Aç ve Bağlan"),
            ),
            const SizedBox(height: 20), // Boşluk eklemek için
            // O anda çalan şarkının bilgilerini göstermek için StreamBuilder
            StreamBuilder<PlayerState>(
              stream: SpotifySdk.subscribePlayerState(), // Spotify çalar durumunu dinliyoruz
              builder: (context, snapshot) {
                // Eğer veri yoksa veya şarkı bilgisi alınamıyorsa
                if (!snapshot.hasData || snapshot.data?.track == null) {
                  return const Text("Müzik bilgisi alınamıyor...");
                }
                // O anda çalan şarkının bilgilerini alıyoruz
                var track = snapshot.data!.track!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start, // Metinleri sola hizala
                  children: [
                    // Şarkının adını göster
                    Text(
                      "Çalan: ${track.name}",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    // Sanatçının adını göster
                    Text(
                      "Sanatçı: ${track.artist.name}",
                      style: TextStyle(fontSize: 16),
                    ),
                    // Albüm adını göster
                    Text(
                      "Albüm: ${track.album.name}",
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20), // Boşluk eklemek için
            // Müzik duraklatmak için bir düğme (Spotify'a bağlıysa etkin)
            ElevatedButton(
              onPressed: _connected ? playMusic : null,
              child: const Text("Müziği Çal"),
            ),
            const SizedBox(height: 10), // Boşluk eklemek için
            ElevatedButton(
              onPressed: _connected ? pauseMusic : null,
              child: const Text("Müziği Duraklat"),
            ),
            const SizedBox(height: 10), // Boşluk eklemek için
            // Sonraki müziğe geçmek için bir düğme (Spotify'a bağlıysa etkin)
            ElevatedButton(
              onPressed: _connected ? skipNext : null,
              child: const Text("Sonraki Müzik"),
            ),
            const SizedBox(height: 10), // Boşluk eklemek için
            // Önceki müziğe geçmek için bir düğme (Spotify'a bağlıysa etkin)
            ElevatedButton(
              onPressed: _connected ? skipPrevious : null,
              child: const Text("Önceki Müzik"),
            ),
          ],
        ),
      ),
    );
  }

  /// Spotify uygulamasını aç ve bağlan
  Future<void> openAndConnectToSpotify() async {
    try {
      // Spotify uygulamasını açmak için URL'yi başlatıyoruz
      const url = 'spotify://';
      if (await canLaunch(url)) {
        await launch(url); // Uygulama başarılı şekilde başlatıldı
      } else {
        print("Spotify uygulaması açılamıyor. Yüklü mü?");
      }

      // Kısa bir bekleme ekliyoruz (isteğe bağlı)
      await Future.delayed(Duration(seconds: 2));

      // Spotify'a bağlanmak için SDK fonksiyonunu çağırıyoruz
      bool result = await SpotifySdk.connectToSpotifyRemote(
        clientId: dotenv.env['CLIENT_ID']!, // CLIENT_ID çevresel değişkeni
        redirectUrl: dotenv.env['REDIRECT_URL']!, // REDIRECT_URL çevresel değişkeni
      );
      // Bağlantı durumunu güncelliyoruz
      setState(() {
        _connected = result;
      });
      if (result) {
        print("Spotify'a başarılı şekilde bağlanıldı!");
      } else {
        print("Spotify'a bağlanılamadı.");
      }
    } on PlatformException catch (e) {
      // Bağlantı hatalarını yakalıyoruz ve ekrana yazdırıyoruz
      print("Bağlantı hatası: ${e.message}");
    }
  }

  /// Müzik duraklatma
  Future<void> playMusic() async {
    try {
      // Spotify'da müziği duraklat
      await SpotifySdk.resume();
    } catch (e) {
      print("Müzik duraklatılamadı: $e");
    }
  }

  /// Müzik duraklatma
  Future<void> pauseMusic() async {
    try {
      // Spotify'da müziği duraklat
      await SpotifySdk.pause();
    } catch (e) {
      print("Müzik duraklatılamadı: $e");
    }
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
