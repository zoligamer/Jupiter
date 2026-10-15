<div align="center">

# 🪐 Jupiter 📱

**Egy modern, gyors és átlátható Neptun kliens egyetemistáknak.**  
*Ne maradj le egyetlen óráról, vizsgáról vagy ösztöndíjról sem!*

---

[![GitHub all releases](https://img.shields.io/github/downloads/zoligamer/Neptun-Mobile-fork/total?style=for-the-badge&logo=github&color=0078D7)](https://github.com/zoligamer/Neptun-Mobile-fork/releases)
[![GitHub release (latest by asset)](https://img.shields.io/github/downloads/zoligamer/Neptun-Mobile-fork/latest/total?style=for-the-badge&logo=android&color=2ea44f)](https://github.com/zoligamer/Neptun-Mobile-fork/releases/latest)
[![Issues](https://img.shields.io/github/issues/zoligamer/Neptun-Mobile-fork?style=for-the-badge&logo=github&color=ff4757)](https://github.com/zoligamer/Neptun-Mobile-fork/issues)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://github.com/zoligamer/Neptun-Mobile-fork/releases)

<br/>

[📥 **Legfrissebb verzió letöltése**](https://github.com/zoligamer/Neptun-Mobile-fork/releases/latest) •
[🐛 **Hibabejelentés & Ötletek**](https://github.com/zoligamer/Neptun-Mobile-fork/issues/new/choose) •
[📜 **Kiadások listája**](https://github.com/zoligamer/Neptun-Mobile-fork/releases)

---

</div>

> [!WARNING]
> **Aktív fejlesztés alatt!**  
> Az alkalmazás folyamatos fejlesztés alatt áll, így előfordulhatnak kisebb hibák vagy hiányosságok. Ha bármilyen problémát tapasztalsz, bátran jelezd a hibabejelentő oldalon! 🛠️

---

## ✨ Főbb funkciók

| Funkció | Leírás |
| :--- | :--- |
| 🔔 **Intelligens értesítések** | Soha nem maradsz le az óráidról, közelgő vizsgáidról és a befizetési határidőkről! |
| 📅 **Áttekinthető órarend & naptár** | Tiszta, logikus heti és havi nézet pontos teremkiírásokkal. |
| 📊 **Jegyek & Kreditek** | Tanulmányi eredmények, átlagok és megszerzett kreditek nyomon követése egy helyen. |
| 💳 **Pénzügyek & Gyűjtőszámla** | Aktuális egyenleg és befizetési kötelezettségek közvetlen elérése az oldalmenüből. |
| 📬 **Üzenetközpont** | Hivatalos oktatói és tanulmányi üzenetek gyors áttekintése. |
| 🎨 **Modern, letisztult UI** | Könnyen kezelhető, ergonomikus felület folyamatos vizuális fejlesztésekkel. |
| ♿ **Akadálymentesítés** | Állítható betűméret, könnyített mód és javított többnyelvű támogatás. |

---

## 🚀 Telepítés & Frissítés

1. Nyisd meg a [Legfrissebb kiadás (Latest Release)](https://github.com/zoligamer/Neptun-Mobile-fork/releases/latest) oldalt.
2. Töltsd le az `.apk` telepítőfájlt a telefonodra.
3. Engedélyezd az ismeretlen forrásból származó alkalmazások telepítését (amennyiben szükséges).
4. Telepítsd az appot, lépj be a Neptun-adataiddal, és kész! 🎉
   *(Az alkalmazás napi automata ellenőrzéssel gondoskodik a frissítésekről).*

---

## 📮 Visszajelzés és hibabejelentés

Találtál egy hibát, furcsán viselkedik az app, vagy van egy jó ötleted az új funkciókra?  
Hozzáadásukkal rengeteget segítesz a projekt fejlődésében!

👉 **[Kattints ide egy Issue / Hibajegy nyitásához!](https://github.com/zoligamer/Neptun-Mobile-fork/issues/new/choose)** 👈

---

## 📝 Verziótörténet (Changelog)

<details open>
<summary><b>✨ Legfrissebb verziók</b></summary>




### 🪐 v2.0.0 (Jupiter Release)
* 🪐 **Új arculat & Jupiter:** Megújult alkalmazásnév, új ikonok és logók, letisztult indítás és első indítási nyelvválasztó kártyák.
* 🎨 **Egységes UI/UX kártyarendszer:** Az összes aloldal (Órarend, Tárgyak, Pénzügyek, Időszakok, Üzenetek) modern, 16px-es kártyákat kapott témakövető finom szegéllyel és háttérrel; a korábbi szürke konténerek eltávolításra kerültek.
* 📊 **Tárgyak & Tanulmányi Dashboard:** Új 3 oszlopos statisztikai összegző (Súlyozott átlag reakció emojival, Ösztöndíjindex, Kreditszámláló), érdemjegy-matrica és céljegy-szimuláció finom haptikával (`AppHaptics.lightImpact()`).
* 🎨 **Komplementer színelméleti kiemelések:** Nyomdai szabályok szerinti vibráló komplementer terem- és kreditkiemelő színek (`roomHighlightColor`) a hardcoded kék helyett minden színpalettához.
* 📑 **Kérvénykezelés modul:** 3 fülös felület (Leadható, Leadott és Megkezdett kérvények), piszkozat-mentés és visszaállítás (`Invalidate`), dinamikus natív űrlapkitöltés és nagyítható A4-es dokumentum-előnézet.
* 🏢 **Aszinkron Tanulmányi Iroda (TO) és kar-ellenőrzés:** Párhuzamosított háttérfolyamat, amely sosem blokkolja az app indítását hálózati késés esetén; valós idejű NYITVA/ZÁRVA sáv és zavartalan órarendi megjelenítés.
* 📅 **Naptár & Idővonal:** Villámgyors (0.05s) azonnali órarend-megjelenítés (`Smart Dual-Cache`), élő napi haladási jelző és a választott témához illeszkedő mély háttérszínek.
* 💳 **Pénzügyek & Időszakok:** Monospace határidő- és összegformázás, státuszkapszulák, valamint időarányos folyamatjelző (progress bar) az aktív időszakokhoz.
* 🧭 **Animált navigáció & Profil:** Visszaállított és réteghelyes ruganyos ("jiggly" / spring physics) csúszó alsó navigáció, élő olvasatlan üzenet badge és perzisztens becenév-beállítás.
* 🛠️ **Stabilitás és minőség:** 0 fordítási és analízis hiba, teljes körű magyar és angol nyelvi frissítés.

### 🚀 v1.0.5
* ✅ **Félévválasztó:** Mostantól félévek szerint is listázhatók a tárgyak és adatok.
* 💰 **Pénzügyek modul:** Javított összegmegjelenítés, és az aktív gyűjtőszámla egyenlegének azonnali kijelzése az oldalmenüben.
* ♿ **Accessibility & Nyelvek:** Könnyed mód, testreszabható betűméret-állítás, javított és működő nyelvi opciók.

### 🧪 v1.0.4
* 🐛 Hibajavítások és stabilitási tesztek a non-alpha kiadáshoz.

### 📦 v1.0.3
* 🧭 Működő alsó navigációs sáv (Bottom Navigation).
* 🔔 Értesítési duplikációk javítva + pontos tanterem kiírása a push üzenetekben.
* 🔄 Napi automata frissítés-ellenőrző rendszer.
* 🔗 Hivatkozások és forrásfájl linkek frissítése.

### 🛠️ v1.0.3 Beta
* 📆 Naptárlogika teljes újraírása, pontos idősávok és állapotjelzők.
* 💼 Pénzügyek, Tárgyak, Üzenetek és Időszakok oldalak stabil működése.
</details>

<details>
<summary><b>📦 Korábbi verziók</b></summary>

### 🔧 v1.0.2
* ♿ Akadálymentesítési funkciók (tesztüzem).
* 🗓️ Naptár nézet integrálása.
* 📱 Megújult oldalmenü.

### 🔐 v1.0.1
* 🛡️ 2FA kétlépcsős azonosítás előkészítése.

### 🏁 v1.0.0
* 🚀 Első nyilvános kiadás: órarend fül és alapszintű bejelentkezési felület.
</details>

---

## 🔮 Hamarosan... (Roadmap)
- [ ] Még mélyebb testreszabhatóság és egyéni témák 🎨
- [ ] Részletesebb vizsganaptár és közvetlen vizsgajelentkezés 📝
- [ ] További stabilitási és sebességoptimalizálások ⚡

---

## 🤝 Készítők & Köszönetnyilvánítás

- **Fork karbantartó & fejlesztő:** [@zoligamer](https://github.com/zoligamer)
- **Eredeti alapok fejlesztője:** Köszönet [@domedav](https://github.com/domedav)-nak az eredeti [Neptun-2](https://github.com/domedav/Neptun-2) projektért! 💙

---

<div align="center">
  <sub>Készült a Neptun-felhasználók idegrendszerének megkímélésére. ☕</sub>
</div>