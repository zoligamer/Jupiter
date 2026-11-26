/* Strict Mode */
"use strict";

/* Constants & Fallbacks */
const REPO_OWNER = "zoligamer";
const REPO_NAME = "Jupiter";
const GITHUB_API_URL = `https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/latest`;
const CACHE_KEY = "jupiter_latest_release_v231_clean";
const CACHE_TTL_MS = 15 * 60 * 1000; // 15 mins

const FALLBACK_RELEASE = {
  tagName: "2.3.1",
  universalUrl: "https://github.com/zoligamer/Jupiter/releases/download/2.3.1/Jupiter_Universal_v2.3.1.apk",
  universalSize: "75.0 MB",
  arm8Url: "https://github.com/zoligamer/Jupiter/releases/download/2.3.1/Jupiter_ARM8_v2.3.1.apk",
  arm8Size: "36.1 MB",
  arm7Url: "https://github.com/zoligamer/Jupiter/releases/download/2.3.1/Jupiter_ARM7_v2.3.1.apk",
  arm7Size: "34.2 MB"
};

/* Showcase Data */
const SHOWCASE_ITEMS = [
  {
    id: "timetable",
    badge: "Gyorsítótárazott Teljesítmény",
    title: "0.05s Instant Órarend & Élő TO-Státusz",
    desc: "Az órarended azonnal betölt az intelligens kettős gyorsítótárból (Smart Dual-Cache). Soha nem maradsz le az óráidról gyenge egyetemi Wi-Fi esetén sem.",
    imgPng: "assets/screenshots/01-timetable.png",
    imgSvg: "assets/screenshots/01-timetable.svg",
    alt: "Jupiter Instant Órarend és TO Nyitvatartás",
    benefits: [
      "Élő idővonal-nyíl mutatja a napközbeni előrehaladásodat",
      "Dinamikusan számolt nyitvatartás: azonnal látod, nyitva van-e a Tanulmányi Hivatal",
      "Letisztult terem- és oktató-megjelenítés zavaró rendszerkódok nélkül"
    ]
  },
  {
    id: "grades",
    badge: "Prediktív Átlagszámítás",
    title: "Szellemjegyek & Ösztöndíj-kalkulátor",
    desc: "Kíváncsi vagy, milyen jegyre van szükséged az ösztöndíjad megtartásához? Adj hozzá szellemjegyeket, és lásd a súlyozott átlagodat valós időben!",
    imgPng: "assets/screenshots/02-grades.png",
    imgSvg: "assets/screenshots/02-grades.svg",
    alt: "Jupiter Szellemjegyek és Tanulmányi Átlag",
    benefits: [
      "Szimuláld a vizsgaeredményeket még a vizsgaidőszak előtt",
      "Korrigált kreditindex és súlyozott tanulmányi átlag automatikus számítása",
      "Dinamikus reakció-emojik és haptikus visszajelzés a jegyeknél"
    ]
  },
  {
    id: "petitions",
    badge: "Teljes Ügyintézési Modul",
    title: "Natív Kérvénykezelő & A4 Nyomtatási Kép",
    desc: "Nem kell PC-t nyitnod a kérvényeid beadásához vagy megtekintéséhez. A Jupiter natív űrlapokkal és többujjas nagyítású A4-es előnézettel rendelkezik.",
    imgPng: "assets/screenshots/03-petitions.png",
    imgSvg: "assets/screenshots/03-petitions.svg",
    alt: "Jupiter Ügyintézés és Kérvények Modul",
    benefits: [
      "Leadható, leadott és piszkozatban lévő kérvények 3 füles áttekintése",
      "Félbehagyott kérelmek biztonságos folytatása vagy szinkronizált elvetése",
      "Tiszta díj-megjelenítés (ingyenes vagy pontos összeg rejtett hibák nélkül)"
    ]
  },
  {
    id: "finances",
    badge: "Tiszta Tranzakciók",
    title: "Intelligens Pénzügyi Szétválasztás",
    desc: "Végre nem keveredik össze a tandíj-kiadás az ösztöndíj-jóváírással. A Jupiter intelligensen kategorizálja a bevételeket és a kötelezettségeket.",
    imgPng: "assets/screenshots/04-finances.png",
    imgSvg: "assets/screenshots/04-finances.svg",
    alt: "Jupiter Pénzügyek és Ösztöndíjak",
    benefits: [
      "Gyűjtőszámlás belső egyenlegfeltöltéseket nem számolja duplán kiadásként",
      "Monospace határidők és tiszta fizetési státuszok (PAID, PAYABLE, OVERDUE)",
      "Tanulmányi, szociális és HÖK támogatások pozitív bevételként kezelve"
    ]
  },
  {
    id: "widgets",
    badge: "Kezdőképernyő Integráció",
    title: "7 db Natív Widget & Master Hub",
    desc: "Tedd ki az órarendedet, egyenlegedet, kreditjeidet vagy a Master Hub widgetet közvetlenül az Android kezdőképernyődre. Valós idejű szinkronizáció háttérbeli akkumulátorkímélő motorral.",
    imgPng: "assets/screenshots/06-widgets.svg",
    imgSvg: "assets/screenshots/06-widgets.svg",
    alt: "Jupiter Android Kezdőképernyő Widgetek és Master Hub",
    benefits: [
      "Következő óra widget visszaszámlálóval és kiemelt teremkóddal",
      "Gyűjtőszámla és fizetési státusz widget egyetlen érintéssel",
      "Mindent összefogó Master Hub widget (üzenetek, kreditek, határidők)"
    ]
  },
  {
    id: "themes",
    badge: "30+ Téma & Testreszabás",
    title: "Bolygóközi Témák & Szezonális Események",
    desc: "Válassz a több mint 30 egyedi színtéma közül (Jovian Amber, Midnight Ocean, Cyberpunk, Forest Emerald, AMOLED E-Ink stb.). Szezonális ünnepi témák és finom fizika-alapú rugózó menü.",
    imgPng: "assets/screenshots/05-themes.png",
    imgSvg: "assets/screenshots/05-themes.svg",
    alt: "Jupiter Témák és Jiggly Navigáció",
    benefits: [
      "Több mint 30 választható prémium téma és szezonális eseményszínek",
      "Finoman rugózó 'jiggly' alsó menü fizikai spring animációval",
      "Dinamikusan számolt komplementer teremkiemelő színek (Hue + 180°)"
    ]
  }
];

/* Theme Engine */
function initThemeEngine() {
  const toggleBtn = document.getElementById("theme-toggle-btn");
  const storedTheme = localStorage.getItem("jupiter-theme");
  
  if (storedTheme === "light" || storedTheme === "dark") {
    document.documentElement.setAttribute("data-theme", storedTheme);
  } else {
    const prefersDark = window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches;
    const initialTheme = prefersDark ? "dark" : "light";
    document.documentElement.setAttribute("data-theme", initialTheme);
  }
  
  if (toggleBtn) {
    toggleBtn.addEventListener("click", () => {
      const current = document.documentElement.getAttribute("data-theme") || "light";
      const next = current === "dark" ? "light" : "dark";
      document.documentElement.setAttribute("data-theme", next);
      localStorage.setItem("jupiter-theme", next);
    });
  }
}

/* Helpers */
function formatBytes(bytes) {
  if (!bytes || isNaN(bytes)) return "";
  const mb = bytes / (1024 * 1024);
  return `${mb.toFixed(1)} MB`;
}

/* Exact Real-Time Download Counter (All GitHub Releases Sum) */
const ALL_RELEASES_API_URL = `https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases?per_page=100`;
const EXACT_DOWNLOADS_CACHE_KEY = "jupiter_exact_downloads_count";
const VERIFIED_EXACT_BASELINE = 129; // Live verified sum across GitHub releases (matches Shields.io total)

async function fetchDownloadStats() {
  const planetCountElem = document.getElementById("planet-download-count");
  const brandCountElem = document.getElementById("brand-download-count");
  const hubCountElem = document.getElementById("hub-total-downloads");
  if (!planetCountElem && !brandCountElem && !hubCountElem) return;

  let totalCount = VERIFIED_EXACT_BASELINE;

  // Check cached count if available
  try {
    const cached = localStorage.getItem(EXACT_DOWNLOADS_CACHE_KEY);
    if (cached) {
      const parsed = parseInt(cached, 10);
      if (!isNaN(parsed) && parsed >= VERIFIED_EXACT_BASELINE) {
        totalCount = parsed;
      }
    }
  } catch (e) {}

  try {
    const res = await fetch(ALL_RELEASES_API_URL, {
      headers: { "Accept": "application/vnd.github.v3+json" }
    });
    if (res.ok) {
      const releases = await res.json();
      if (Array.isArray(releases)) {
        let liveSum = 0;
        for (const rel of releases) {
          if (Array.isArray(rel.assets)) {
            for (const asset of rel.assets) {
              if (typeof asset.download_count === "number") {
                liveSum += asset.download_count;
              }
            }
          }
        }
        if (liveSum >= VERIFIED_EXACT_BASELINE) {
          totalCount = liveSum;
          try {
            localStorage.setItem(EXACT_DOWNLOADS_CACHE_KEY, totalCount.toString());
          } catch (e) {}
        }
      }
    }
  } catch (e) {
    // Graceful fallback to verified exact baseline
  }

  // Exact integer display: NO suffix (+), NO floats!
  animateCount(planetCountElem, totalCount, "");
  animateCount(brandCountElem, totalCount, "");
  animateCount(hubCountElem, totalCount, "");
}

function animateCount(elem, target, suffix = "") {
  if (!elem) return;
  const start = 0;
  const duration = 1200;
  const startTime = performance.now();

  function update(currentTime) {
    const elapsed = currentTime - startTime;
    const progress = Math.min(elapsed / duration, 1);
    // easeOutQuad
    const ease = 1 - (1 - progress) * (1 - progress);
    const current = Math.floor(start + (target - start) * ease);
    elem.textContent = `${current}${suffix}`;
    if (progress < 1) {
      requestAnimationFrame(update);
    } else {
      elem.textContent = `${target}${suffix}`;
    }
  }
  requestAnimationFrame(update);
}

/* GitHub Releases API */
async function fetchLatestRelease() {
  // Check session cache
  try {
    const cached = sessionStorage.getItem(CACHE_KEY);
    if (cached) {
      const parsed = JSON.parse(cached);
      if (Date.now() - parsed.timestamp < CACHE_TTL_MS) {
        applyReleaseData(parsed.data);
        return;
      }
    }
  } catch (e) {
    // Ignore cache error
  }

  try {
    const res = await fetch(GITHUB_API_URL, {
      headers: { "Accept": "application/vnd.github.v3+json" }
    });
    
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();
    
    const releaseInfo = parseReleasePayload(data);
    applyReleaseData(releaseInfo);
    
    // Store cache
    try {
      sessionStorage.setItem(CACHE_KEY, JSON.stringify({
        timestamp: Date.now(),
        data: releaseInfo
      }));
    } catch (e) {}
    
  } catch (err) {
    // Graceful fallback to verified constant
    applyReleaseData(FALLBACK_RELEASE);
  }
}

function parseReleasePayload(data) {
  const tagName = (data.tag_name || "").replace(/^v/, "");
  const assets = data.assets || [];
  
  let universal = null;
  let arm8 = null;
  let arm7 = null;

  for (const asset of assets) {
    const name = asset.name.toLowerCase();
    if (!name.endsWith(".apk")) continue;
    if (name.includes("universal")) {
      universal = asset;
    } else if (name.includes("arm8") || name.includes("arm64") || name.includes("v8a")) {
      arm8 = asset;
    } else if (name.includes("arm7") || name.includes("armv7") || name.includes("v7a")) {
      arm7 = asset;
    }
  }

  return {
    tagName: tagName || FALLBACK_RELEASE.tagName,
    universalUrl: universal ? universal.browser_download_url : FALLBACK_RELEASE.universalUrl,
    universalSize: universal ? formatBytes(universal.size) : FALLBACK_RELEASE.universalSize,
    arm8Url: arm8 ? arm8.browser_download_url : (universal ? universal.browser_download_url : FALLBACK_RELEASE.arm8Url),
    arm8Size: arm8 ? formatBytes(arm8.size) : FALLBACK_RELEASE.arm8Size,
    arm7Url: arm7 ? arm7.browser_download_url : (universal ? universal.browser_download_url : FALLBACK_RELEASE.arm7Url),
    arm7Size: arm7 ? formatBytes(arm7.size) : FALLBACK_RELEASE.arm7Size,
    publishedAt: data.published_at || null,
    body: data.body || null
  };
}

function applyReleaseData(rel) {
  // Hero Universal CTA
  const heroBtn = document.getElementById("hero-universal-btn");
  const heroVer = document.getElementById("hero-universal-version");
  const heroSize = document.getElementById("hero-universal-size");
  
  if (heroBtn && rel.universalUrl) heroBtn.href = rel.universalUrl;
  if (heroVer && rel.tagName) heroVer.textContent = `v${rel.tagName}`;
  if (heroSize && rel.universalSize) heroSize.textContent = rel.universalSize;

  // Download Hub Universal Card
  const cardUnivBtn = document.getElementById("card-universal-btn");
  const cardUnivVer = document.getElementById("card-universal-version");
  const cardUnivSize = document.getElementById("card-universal-size");
  
  if (cardUnivBtn && rel.universalUrl) cardUnivBtn.href = rel.universalUrl;
  if (cardUnivVer && rel.tagName) cardUnivVer.textContent = `v${rel.tagName}`;
  if (cardUnivSize && rel.universalSize) cardUnivSize.textContent = rel.universalSize;

  // Split ARM8 Card
  const cardArm8Btn = document.getElementById("card-arm8-btn");
  const cardArm8Ver = document.getElementById("card-arm8-version");
  const cardArm8Size = document.getElementById("card-arm8-size");
  if (cardArm8Btn && rel.arm8Url) cardArm8Btn.href = rel.arm8Url;
  if (cardArm8Ver && rel.tagName) cardArm8Ver.textContent = `v${rel.tagName}`;
  if (cardArm8Size && rel.arm8Size) cardArm8Size.textContent = rel.arm8Size;

  // Split ARM7 Card
  const cardArm7Btn = document.getElementById("card-arm7-btn");
  const cardArm7Ver = document.getElementById("card-arm7-version");
  const cardArm7Size = document.getElementById("card-arm7-size");
  if (cardArm7Btn && rel.arm7Url) cardArm7Btn.href = rel.arm7Url;
  if (cardArm7Ver && rel.tagName) cardArm7Ver.textContent = `v${rel.tagName}`;
  if (cardArm7Size && rel.arm7Size) cardArm7Size.textContent = rel.arm7Size;

  // Update changelog version tag if present
  const changeVer = document.getElementById("changelog-version-tag");
  if (changeVer && rel.tagName) changeVer.textContent = `v${rel.tagName}`;
}

/* Showcase Controller */
function initShowcase() {
  const tabsContainer = document.getElementById("showcase-tabs");
  const screenImg = document.getElementById("showcase-screen-img");
  const badgeElem = document.getElementById("showcase-badge");
  const titleElem = document.getElementById("showcase-title");
  const descElem = document.getElementById("showcase-desc");
  const benefitsList = document.getElementById("showcase-benefits");

  if (!tabsContainer || !screenImg) return;

  tabsContainer.addEventListener("click", (e) => {
    const btn = e.target.closest(".tab-btn");
    if (!btn) return;
    
    const index = parseInt(btn.getAttribute("data-index"), 10);
    if (isNaN(index) || !SHOWCASE_ITEMS[index]) return;

    // Toggle active tab style and accessibility attributes
    tabsContainer.querySelectorAll(".tab-btn").forEach(b => {
      b.classList.remove("active");
      b.setAttribute("aria-selected", "false");
    });
    btn.classList.add("active");
    btn.setAttribute("aria-selected", "true");

    const item = SHOWCASE_ITEMS[index];

    // Image transition with fallback
    screenImg.style.opacity = "0.2";
    setTimeout(() => {
      screenImg.src = item.imgPng;
      screenImg.alt = item.alt;
      screenImg.onerror = () => {
        screenImg.onerror = null;
        screenImg.src = item.imgSvg;
      };
      screenImg.style.opacity = "1";
    }, 150);

    // Update text details
    if (badgeElem) badgeElem.textContent = item.badge;
    if (titleElem) titleElem.textContent = item.title;
    if (descElem) descElem.textContent = item.desc;

    if (benefitsList) {
      benefitsList.innerHTML = item.benefits
        .map(b => `
          <li class="feature-benefit-item">
            <span class="benefit-bullet">✓</span>
            <span>${b}</span>
          </li>
        `)
        .join("");
    }
  });
}

/* Interactive Theme Swatches */
function initThemeSwatches() {
  const frame = document.querySelector(".phone-mockup-frame");
  const swatches = document.querySelectorAll(".theme-swatch-btn");
  if (!frame || !swatches.length) return;

  swatches.forEach(btn => {
    btn.addEventListener("click", () => {
      swatches.forEach(s => s.classList.remove("active"));
      btn.classList.add("active");
      const glow = btn.getAttribute("data-glow") || "rgba(249, 115, 22, 0.25)";
      frame.style.setProperty("--mockup-glow", glow);
    });
  });
}

/* Screenshot Lightbox */
function initScreenshotLightbox() {
  const screen = document.querySelector(".phone-screen");
  const screenImg = document.getElementById("showcase-screen-img");
  const lightbox = document.getElementById("screenshot-lightbox");
  const lightboxImg = document.getElementById("lightbox-img");
  const closeBtn = document.getElementById("lightbox-close-btn");
  if (!screen || !screenImg || !lightbox || !lightboxImg) return;

  screen.addEventListener("click", () => {
    lightboxImg.src = screenImg.src;
    lightboxImg.alt = screenImg.alt;
    if (typeof lightbox.showModal === "function") {
      lightbox.showModal();
    }
  });

  if (closeBtn) {
    closeBtn.addEventListener("click", () => lightbox.close());
  }

  lightbox.addEventListener("click", (e) => {
    if (e.target === lightbox) {
      lightbox.close();
    }
  });
}

/* University Search Filter */
function initUniversitySearch() {
  const searchInput = document.getElementById("uni-search-input");
  const tags = document.querySelectorAll(".uni-tag");
  const countPill = document.getElementById("uni-count-pill");
  if (!searchInput || !tags.length) return;

  searchInput.addEventListener("input", () => {
    const query = searchInput.value.toLowerCase().trim();
    let visibleCount = 0;
    tags.forEach(tag => {
      const text = tag.textContent.toLowerCase();
      if (!query || text.includes(query)) {
        tag.style.display = "";
        visibleCount++;
      } else {
        tag.style.display = "none";
      }
    });
    if (countPill) {
      countPill.textContent = query ? `${visibleCount} találat` : "50+ intézmény";
    }
  });
}

/* Clipboard */
function initClipboard() {
  // Git Clone Copy
  const copyCloneBtn = document.getElementById("copy-clone-btn");
  const cloneCmdText = "git clone https://github.com/zoligamer/Jupiter.git";
  
  if (copyCloneBtn) {
    copyCloneBtn.addEventListener("click", async () => {
      try {
        await navigator.clipboard.writeText(cloneCmdText);
        const originalText = copyCloneBtn.textContent;
        copyCloneBtn.textContent = "Másolva!";
        setTimeout(() => {
          copyCloneBtn.textContent = originalText;
        }, 2000);
      } catch (err) {}
    });
  }
}

/* Mobile Menu */
function initMobileMenu() {
  const toggleBtn = document.getElementById("mobile-menu-btn");
  const navLinks = document.getElementById("nav-links");
  
  if (toggleBtn && navLinks) {
    const closeMenu = () => navLinks.classList.remove("open");

    toggleBtn.addEventListener("click", (e) => {
      e.stopPropagation();
      navLinks.classList.toggle("open");
    });
    
    navLinks.querySelectorAll("a").forEach(link => {
      link.addEventListener("click", closeMenu);
    });

    // Close on Escape
    document.addEventListener("keydown", (e) => {
      if (e.key === "Escape" && navLinks.classList.contains("open")) {
        closeMenu();
      }
    });

    // Close on outside clicks
    document.addEventListener("click", (e) => {
      if (navLinks.classList.contains("open") && !navLinks.contains(e.target) && e.target !== toggleBtn) {
        closeMenu();
      }
    });
  }
}

/* Tally Feedback Button */
function initFeedbackButton() {
  const btn = document.getElementById("tally-feedback-btn");
  if (!btn) return;
  btn.addEventListener("click", () => {
    if (!window.Tally) {
      window.open("https://tally.so/r/2jX62M", "_blank");
    }
  });
}

/* Language Engine (HU / EN) */
const I18N = {
  hu: {
    nav_download: "Letöltés",
    nav_showcase: "Funkciók & Képek",
    nav_features: "Előnyök",
    nav_faq: "GYIK & Biztonság",
    nav_ios: "iOS Verzió",
    nav_developer: "Fejlesztők & Források",
    nav_cta: "Letöltés",
    brand_dl_label: "letöltés",
    planet_dl_label: "letöltés",
    planet_badge_live: "ÉLŐ MÉRŐ",
    hero_pill_status: "Android: Elérhető (v2.3.1)",
    hero_pill_ios: "iOS: Fejlesztés alatt (PWA elérhető)",
    hero_title: 'Töltsd le a <span class="hero-title-highlight">Jupiter klienst</span> a telefonodra!',
    hero_desc: "Egy modern, villámgyors és átlátható egyetemi kliens a lassú hivatalos Neptun mobilapp helyett. Nincsenek elrejtett menük vagy bosszantó hibák: csak néhány érintés, és a kezedben a zökkenőmentes egyetemi félév.",
    hero_btn_title: "Universal APK Letöltése",
    hero_btn_sub: "Minden Android telefonra • Frissítési értesítővel • Play Protect-tiszta",
    hero_helper: "💡 Nincs szükség találgatásra: bármely Android készüléken azonnal fut.",
    hero_split: "Kisebb méretű architektúra APK-k ↓",
    hero_dl_label: "Letöltés a GitHubon",
    giant_title: "Egyetemi Hallgató Töltötte Már Le",
    hub_tag: "Letöltési Központ",
    hub_title: "Válaszd ki a telefonodhoz illő csomagot",
    hub_sub: "A Universal csomag azonnal működik minden eszközön. Haladó felhasználóknak kisebb letöltési méretű, processzorra optimalizált APK-kat is biztosítunk.",
    hub_stat1: "Összesített Letöltés a GitHubon",
    hub_stat2: "Támogatott Magyar Intézmény",
    hub_stat3: "Gyorsítótárazott Órarend",
    faq_tag: "GYIK & Biztonság",
    faq_title: "Gyakran Ismételt Kérdések",
    faq_sub: "Minden fontos tudnivaló a telepítésről, az adatbiztonságról és a Google Play Protect működéséről."
  },
  en: {
    nav_download: "Download",
    nav_showcase: "Showcase & Screens",
    nav_features: "Features",
    nav_faq: "FAQ & Safety",
    nav_ios: "iOS Version",
    nav_developer: "Developers",
    nav_cta: "Download",
    brand_dl_label: "downloads",
    planet_dl_label: "downloads",
    planet_badge_live: "LIVE METRIC",
    hero_pill_status: "Android: Available (v2.3.1)",
    hero_pill_ios: "iOS: Under Development (PWA Ready)",
    hero_title: 'Download the <span class="hero-title-highlight">Jupiter Client</span> for your phone!',
    hero_desc: "A modern, blazingly fast and transparent university student client instead of the sluggish official Neptun mobile app. No hidden menus or frustrating bugs: complete peace of mind for your semester.",
    hero_btn_title: "Download Universal APK",
    hero_btn_sub: "For all Android phones • Update notifier • Play Protect clean",
    hero_helper: "💡 No guesswork: works seamlessly on all Android devices.",
    hero_split: "Smaller architecture-specific APKs ↓",
    hero_dl_label: "Downloads on GitHub",
    giant_title: "University Students Downloaded",
    hub_tag: "Download Hub",
    hub_title: "Select the perfect package for your device",
    hub_sub: "The Universal package runs immediately on all devices. For power users, processor-optimized APKs with smaller sizes are also available.",
    hub_stat1: "Total Downloads on GitHub",
    hub_stat2: "Supported Universities",
    hub_stat3: "Cached Instant Timetable",
    faq_tag: "FAQ & Safety",
    faq_title: "Frequently Asked Questions",
    faq_sub: "Everything you need to know about installation, privacy, 2FA, and Google Play Protect safety."
  }
};

function setLanguage(lang) {
  if (lang !== "hu" && lang !== "en") lang = "hu";
  localStorage.setItem("jupiter-lang", lang);
  document.documentElement.setAttribute("lang", lang);

  const dict = I18N[lang];
  if (!dict) return;

  document.querySelectorAll("[data-i18n]").forEach(elem => {
    const key = elem.getAttribute("data-i18n");
    if (dict[key]) {
      elem.innerHTML = dict[key];
    }
  });

  const huLabel = document.getElementById("lang-hu-label");
  const enLabel = document.getElementById("lang-en-label");
  if (huLabel && enLabel) {
    if (lang === "en") {
      huLabel.classList.remove("active");
      enLabel.classList.add("active");
    } else {
      enLabel.classList.remove("active");
      huLabel.classList.add("active");
    }
  }
}

function initLanguageEngine() {
  const toggleBtn = document.getElementById("lang-toggle-btn");
  const currentLang = localStorage.getItem("jupiter-lang") || "hu";
  setLanguage(currentLang);

  if (toggleBtn) {
    toggleBtn.addEventListener("click", () => {
      const active = document.documentElement.getAttribute("lang") || "hu";
      const next = active === "hu" ? "en" : "hu";
      setLanguage(next);
    });
  }
}

/* DOM Ready */
document.addEventListener("DOMContentLoaded", () => {
  initThemeEngine();
  initLanguageEngine();
  fetchDownloadStats();
  fetchLatestRelease();
  initShowcase();
  initThemeSwatches();
  initScreenshotLightbox();
  initUniversitySearch();
  initClipboard();
  initMobileMenu();
  initFeedbackButton();
});
