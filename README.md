# Mental Dönüşüm

macOS için DeepL benzeri hızlı çeviri uygulaması. Apple'ın yerleşik **Translation** framework'ünü kullanır — API anahtarı, internet bağlantısı veya abonelik gerekmez (dil paketleri ilk kullanımda indirilir).

## Özellikler

- Menü çubuğunda küçük ikon, tek tıkla erişim
- Global kısayol: **⌘ + Shift + T** — herhangi bir uygulamadan tetikle, pano içeriğini otomatik çevirsin
- Yan yana iki panel: yazdıkça/yapıştırdıkça otomatik çeviri (400 ms gecikmeli debounce)
- 20+ dil arası çeviri, otomatik kaynak dil algılama
- Dilleri tek tuşla takas etme
- Sonucu tek tuşla panoya kopyalama

## Gereksinimler

- macOS 15.0 (Sequoia) veya daha yenisi — `Translation` framework için
- Xcode 16 veya daha yenisi

## Çalıştırma

```bash
git clone https://github.com/mahmali/mental-donusum.git
cd mental-donusum
open MentalDonusum.xcodeproj
```

Xcode'da **▶ Run** (⌘R) tuşuna basın.

İlk çeviride sistem, ilgili dil paketinin indirilmesi için izin sorabilir — "İzin Ver"e tıklayın.

## Kısayollar

| Kısayol | Aksiyon |
|---------|---------|
| ⌘ + Shift + T | Çevirmeni aç, panodaki metni otomatik çevir |
| ⌘ + Q | Uygulamadan çık |

## Mimari

```
MentalDonusum/
├── MentalDonusumApp.swift   # @main, MenuBarExtra ve menü içeriği
├── AppDelegate.swift        # NSWindow yönetimi, hotkey kaydı
├── HotkeyManager.swift      # Carbon ile global hotkey
├── ContentView.swift        # İki panelli çevirmen UI
└── LanguagePicker.swift     # Dil seçici + dil kataloğu
```

## Lisans

MIT
