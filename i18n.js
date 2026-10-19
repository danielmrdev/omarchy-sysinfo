var translations = {
  en: {
    title: "System Info",
    metricsSubtitle: "LIVE SYSTEM METRICS",
    unavailable: "Unavailable",
    cpu: "CPU",
    memory: "MEMORY",
    cpuCores: "CPU CORES",
    storage: "STORAGE",
    thermals: "THERMALS",
    temperature: "TEMPERATURE",
    fan: "FAN",
    openBtop: "Open btop",
    tooltipRam: "RAM",
    tooltipDisk: "Disk /",
    tooltipTemp: "Temp",
    about: "About",
    metrics: "Metrics",
    aboutDeveloper: "Developer",
    aboutLinks: "Help & links",
    aboutChangelog: "What's new",
    aboutMarketplace: "Omarchy Marketplace",
    aboutIssue: "Report a problem",
    aboutGithub: "GitHub repository",
    uiLanguage: "Interface language",
    uiLanguageSystem: "System",
    uiLanguageEn: "English",
    uiLanguageEs: "Español"
  },
  es: {
    title: "System Info",
    metricsSubtitle: "MÉTRICAS DEL SISTEMA EN TIEMPO REAL",
    unavailable: "No disponible",
    cpu: "CPU",
    memory: "MEMORIA",
    cpuCores: "NÚCLEOS DE CPU",
    storage: "ALMACENAMIENTO",
    thermals: "TEMPERATURAS",
    temperature: "TEMPERATURA",
    fan: "VENTILADOR",
    openBtop: "Abrir btop",
    tooltipRam: "RAM",
    tooltipDisk: "Disco /",
    tooltipTemp: "Temp.",
    about: "Acerca de",
    metrics: "Métricas",
    aboutDeveloper: "Desarrollador",
    aboutLinks: "Ayuda y enlaces",
    aboutChangelog: "Novedades",
    aboutMarketplace: "Marketplace de Omarchy",
    aboutIssue: "Informar de un problema",
    aboutGithub: "Repositorio en GitHub",
    uiLanguage: "Idioma de la interfaz",
    uiLanguageSystem: "Sistema",
    uiLanguageEn: "English",
    uiLanguageEs: "Español"
  }
}

function languageCode(value) {
  var normalized = String(value || "").trim().toLowerCase()
    .replace(/\..*$/, "")
    .replace(/_/g, "-")
  var language = normalized.split("-")[0]
  return language === "en" || language === "es" ? language : ""
}

function resolveLanguage(localeName, preferredLanguages) {
  if (preferredLanguages && typeof preferredLanguages.length === "number") {
    for (var i = 0; i < preferredLanguages.length; i++) {
      var preferred = languageCode(preferredLanguages[i])
      if (preferred) return preferred
    }
  }
  return languageCode(localeName) || "en"
}

function normalizeOverride(language) {
  var normalized = String(language || "system").trim().toLowerCase()
  return normalized === "en" || normalized === "es" ? normalized : "system"
}

function t(key, language, override) {
  var selectedOverride = normalizeOverride(override)
  var selectedLanguage = selectedOverride === "system"
    ? languageCode(language) || "en"
    : selectedOverride
  var selected = translations[selectedLanguage]
  if (selected[key] !== undefined) return selected[key]
  if (translations.en[key] !== undefined) return translations.en[key]
  return "⟦" + key + "⟧"
}
