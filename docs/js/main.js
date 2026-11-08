/* Strict Mode */
"use strict";

/* Constants & Fallbacks */
const REPO_OWNER = "zoligamer";
const REPO_NAME = "Jupiter";
const GITHUB_API_URL = `https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/latest`;
const CACHE_KEY = "jupiter_latest_release_v220";
const CACHE_TTL_MS = 15 * 60 * 1000; // 15 mins

const FALLBACK_RELEASE = {
  tagName: "2.2.0",
  universalUrl: "https://github.com/zoligamer/Jupiter/releases/download/2.2.0/Jupiter_Universal_v2.2.0.apk",
  universalSize: "71.4 MB",
  arm8Url: "https://github.com/zoligamer/Jupiter/releases/download/2.2.0/Jupiter_v2.2.0_ARM8.apk",
  arm8Size: "33.5 MB",
  arm7Url: "https://github.com/zoligamer/Jupiter/releases/download/2.2.0/Jupiter_v2.2.0_ARM7.apk",
  arm7Size: "31.3 MB",
  universalSha1: "804d9a334f3e65b34e822facaed1d2d66ab7298f"
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
    id: "themes",
    badge: "Testreszabhatóság",
    title: "Bolygóközi Témák & Fizika-alapú Navigáció",
    desc: "Válassz a Jovian Amber, Midnight Ocean, Cyberpunk Violet, E-Ink vagy Forest témák közül. A dinamikus színharmónia automatikusan igazítja az akcentusszíneket.",
    imgPng: "assets/screenshots/05-themes.png",
    imgSvg: "assets/screenshots/05-themes.svg",
    alt: "Jupiter Témák és Jiggly Navigáció",
    benefits: [
      "Finoman rugózó 'jiggly' alsó menü fizikai spring animációval",
      "Dinamikusan számolt komplementer teremkiemelő színek (Hue + 180°)",
      "Valós idejű olvasatlan üzenet-számláló jelvény a navigációs sávon"
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
  let sha1Asset = null;

  for (const asset of assets) {
    const name = asset.name.toLowerCase();
    if (name.endsWith(".sha1")) {
      if (name.includes("universal")) sha1Asset = asset;
      continue;
    }
    if (name.includes("universal") && name.endsWith(".apk")) {
      universal = asset;
    } else if ((name.includes("arm8") || name.includes("arm64") || name.includes("v8a")) && name.endsWith(".apk")) {
      arm8 = asset;
    } else if ((name.includes("arm7") || name.includes("armv7") || name.includes("v7a")) && name.endsWith(".apk")) {
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
    universalSha1: FALLBACK_RELEASE.universalSha1,
    sha1Url: sha1Asset ? sha1Asset.browser_download_url : null
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

  // Universal SHA1
  const sha1Elem = document.getElementById("universal-sha1-val");
  if (sha1Elem) {
    if (rel.universalSha1) sha1Elem.textContent = rel.universalSha1;
    if (rel.sha1Url) {
      fetch(rel.sha1Url)
        .then(r => r.text())
        .then(hash => {
          const cleaned = hash.trim().split(/\s+/)[0];
          if (cleaned && cleaned.length >= 20) sha1Elem.textContent = cleaned;
        })
        .catch(() => {});
    }
  }
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

    // Toggle active tab style
    tabsContainer.querySelectorAll(".tab-btn").forEach(b => b.classList.remove("active"));
    btn.classList.add("active");

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

  // SHA1 Copy
  const copySha1Btn = document.getElementById("copy-sha1-btn");
  if (copySha1Btn) {
    copySha1Btn.addEventListener("click", async () => {
      const sha1Val = document.getElementById("universal-sha1-val")?.textContent || "";
      if (!sha1Val) return;
      try {
        await navigator.clipboard.writeText(sha1Val.trim());
        const orig = copySha1Btn.textContent;
        copySha1Btn.textContent = "Másolva!";
        setTimeout(() => {
          copySha1Btn.textContent = orig;
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
    toggleBtn.addEventListener("click", () => {
      navLinks.classList.toggle("open");
    });
    
    navLinks.querySelectorAll("a").forEach(link => {
      link.addEventListener("click", () => {
        navLinks.classList.remove("open");
      });
    });
  }
}

/* DOM Ready */
document.addEventListener("DOMContentLoaded", () => {
  initThemeEngine();
  fetchLatestRelease();
  initShowcase();
  initClipboard();
  initMobileMenu();
});
