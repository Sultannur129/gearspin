# Firebase & Cloud Services Kurulum ve Entegrasyon Rehberi

**Gear Spin: Tap & Hit** projesinde Android ve iOS paket adları tamamen eşitlenmiştir:
- **Android Application ID:** `com.nexalo.gearspin`
- **iOS Bundle Identifier:** `com.nexalo.gearspin`

Uygulama **Offline-First** mimariyle kodlanmıştır. Firebase kurulu olmadığında uygulama çökmez; otomatik olarak yerel misafir (offline guest) modunda çalışır. Canlı Firebase veritabanına ve Google ile girişe bağlanmak için aşağıdaki adımları izleyin.

---

## 1. Firebase Projesi Oluşturma
1. [Firebase Console](https://console.firebase.google.com/)'a gidin ve yeni bir proje oluşturun (örn: `gearspin-game`).
2. Google Analytics'i isteğe bağlı olarak etkinleştirebilirsiniz.

---

## 2. Otomatik Kurulum (Önerilen: FlutterFire CLI)

En hızlı ve hatasız yöntem FlutterFire CLI kullanmaktır:

1. Terminalde Firebase CLI ve FlutterFire CLI araçlarını kurun/güncelleyin:
   ```bash
   npm install -g firebase-tools
   firebase login
   dart pub global activate flutterfire_cli
   ```

2. Proje ana dizininde (`c:\Users\sulta\Documents\GearSpin`) şu komutu çalıştırın:
   ```bash
   flutterfire configure
   ```
3. Konsolda oluşturduğunuz Firebase projesini seçin ve **Android** ile **iOS** platformlarını işaretleyin.
4. Bu komut:
   - `lib/firebase_options.dart` dosyasını otomatik oluşturur,
   - `android/app/google-services.json` dosyasını indirip yerleştirir,
   - `ios/Runner/GoogleService-Info.plist` dosyasını iOS projesine bağlar.

---

## 3. Manuel Kurulum Adımları (Alternatif)

Eğer CLI kullanmak istemiyorsanız:

### Android:
1. Firebase Console > **Project Settings** > **Add App** > **Android** seçin.
2. Package name olarak `com.nexalo.gearspin` girin.
3. İndirilen `google-services.json` dosyasını `android/app/google-services.json` konumuna yapıştırın.
4. `android/settings.gradle` dosyasındaki `plugins` bloğuna ekleyin:
   ```groovy
   id "com.google.gms.google-services" version "4.4.2" apply false
   ```
5. `android/app/build.gradle` dosyasındaki `plugins` bloğuna ekleyin:
   ```groovy
   id "com.google.gms.google-services"
   ```

### iOS:
1. Firebase Console > **Add App** > **iOS** seçin.
2. Bundle ID olarak `com.nexalo.gearspin` girin.
3. `GoogleService-Info.plist` dosyasını indirin.
4. Xcode ile `ios/Runner.xcworkspace` projesini açıp dosyayı `Runner` klasörü altına ("Copy items if needed" seçili olarak) sürükleyin.

---

## 4. Firebase Console Üzerinde Açılması Gereken Servisler

### A. Authentication (Kimlik Doğrulama)
1. Firebase Console > **Authentication** > **Get Started**.
2. **Sign-in method** sekmesine gidin:
   - **Anonymous (Anonim):** Etkinleştirin (Misafir oyuncuların skorlarını tutmak için zorunludur).
   - **Google:** Etkinleştirin ve destek e-postanızı seçin.
3. *Google Sign-In Android SHA-1 Notu:*
   Android cihazlarda Google ile giriş yapabilmek için SHA-1 parmak izinizi Firebase Console'daki Android uygulamanıza eklemeniz gerekir:
   ```bash
   cd android
   ./gradlew signingReport
   ```
   Çıkan `SHA1` değerini kopyalayıp Firebase Proje Ayarları > Android Uygulamanız > **SHA Certificate Fingerprints** alanına yapıştırın.

### B. Cloud Firestore (Küresel Sıralama ve Profil)
1. Firebase Console > **Firestore Database** > **Create Database**.
2. Konum olarak size en yakın bölgeyi (örn: `eur3` veya `europe-west3`) seçin.
3. **Rules (Kurallar)** sekmesini açın ve projemizdeki [firestore.rules](firestore.rules) içeriğini yapıştırıp **Publish** butonuna tıklayın.

---

## 5. Uygulamayı Firebase Modunda Çalıştırma

Tüm adımlar tamamlandığında oyunu canlı bulut senkronizasyonu ile başlatmak için:

```bash
flutter run --dart-define=USE_FIREBASE=true
```

Tebrikler! Artık kullanıcılar:
- Gerçek zamanlı dünya sıralamasında yarışabilir,
- Google hesaplarını bağlayarak skorlarını ve satın aldıkları skin/No-Ads haklarını koruyabilir,
- Başka cihazlara geçtiklerinde kaldıkları yerden devam edebilirler!
