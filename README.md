# Instant Translate (Mental Dönüşüm)

macOS için DeepL benzeri hızlı çeviri uygulaması. Apple'ın yerleşik **Translation** framework'ünü kullanır — API anahtarı, internet bağlantısı veya abonelik gerekmez (dil paketleri ilk kullanımda indirilir).

> macOS 15 (Sequoia) veya daha yenisi gerekir.

## Kurulum (DMG)

1. [Releases](https://github.com/mahmali/instant-translate-mac/releases) sayfasından en güncel `.dmg` dosyasını indirin (veya bu repo'yu klonlayıp `./scripts/make_dmg.sh` ile yerel olarak üretin)
2. DMG'yi açın ve **MentalDonusum.app**'i **Applications** klasörüne sürükleyin
3. İlk açılışta macOS "tanınmayan geliştirici" uyarısı verirse: Finder → Applications → MentalDonusum.app'a **sağ tık → Aç** (bir defalık)

## Özellikler

- Menü çubuğunda küçük ikon, tek tıkla erişim
- Yapılandırılabilir global kısayol (varsayılan **⌘⇧T**) — herhangi bir uygulamadan tetikle, pano içeriği otomatik çevrilsin
- Yan yana iki panel: yazdıkça/yapıştırdıkça otomatik çeviri (400 ms debounce)
- 20+ dil arası çeviri, **NaturalLanguage** ile otomatik kaynak dil algılama
- Dosyadan çeviri (.txt, .md, .rtf, .html) ve sonucu kaydetme
- Geçmiş: son 200 çeviri saklanır, aranabilir
- Üç modlu tema (sistem / aydınlık / karanlık)
- Tek tuşla dil değiştirme, sonucu panoya kopyalama

## Kısayollar

| Kısayol | Aksiyon |
|---------|---------|
| ⌘⇧T (yapılandırılabilir) | Çevirmeni aç + panodaki metni çevir |
| ⌘O | Dosyadan çeviri |
| ⌘S | Çeviriyi dosyaya kaydet |
| ⌘⇧C | Çeviriyi kopyala |
| ⌘Y | Geçmiş |
| ⌘, | Ayarlar |
| ⌘Q | Çıkış |

## Geliştirici notları

```bash
git clone https://github.com/mahmali/instant-translate-mac.git
cd instant-translate-mac
open MentalDonusum.xcodeproj          # Xcode'da çalıştır
# veya
./scripts/make_dmg.sh                 # DMG paketi üret (dist/ içine)
```

### Mimari

```
MentalDonusum/
├── MentalDonusumApp.swift   # @main, MenuBarExtra ve menü içeriği
├── AppDelegate.swift        # NSWindow yönetimi, hotkey kaydı, tema uygulanması
├── HotkeyManager.swift      # Carbon ile yapılandırılabilir global hotkey
├── ContentView.swift        # İki panelli çevirmen UI + özel NSTextView wrapper
├── LanguagePicker.swift     # Dil seçici + dil kataloğu
├── Settings.swift           # Ayarlar sheet'i + hotkey kaydedici
└── History.swift            # JSON tabanlı geçmiş + arama
```

```
scripts/
├── generate_icon.swift   # AppIcon PNG'lerini üretir
└── make_dmg.sh           # Release derleme + DMG paketleme
```

## Gereksinimler

- macOS 15.0 (Sequoia) — `Translation` framework için
- Xcode 16 veya daha yenisi (geliştirme için)

## Lisans

MIT
