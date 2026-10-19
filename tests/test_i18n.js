#!/usr/bin/env node
"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const context = {};
vm.createContext(context);
vm.runInContext(
  fs.readFileSync(path.join(__dirname, "..", "i18n.js"), "utf8"),
  context,
  { filename: "i18n.js" }
);

assert.deepEqual(
  Object.keys(context.translations.en).sort(),
  Object.keys(context.translations.es).sort(),
  "English and Spanish catalogs must have matching keys"
);
assert.equal(context.resolveLanguage("es-ES"), "es");
assert.equal(context.resolveLanguage("es_ES.UTF-8"), "es");
assert.equal(context.resolveLanguage("es.utf8"), "es");
assert.equal(context.resolveLanguage("en_US", ["es-ES"]), "es");
assert.equal(context.resolveLanguage("es_ES", ["fr-FR"]), "es");
assert.equal(context.resolveLanguage("fr_FR"), "en");
assert.equal(context.normalizeOverride("system"), "system");
assert.equal(context.normalizeOverride("en"), "en");
assert.equal(context.normalizeOverride("es"), "es");
assert.equal(context.normalizeOverride("fr"), "system");
assert.equal(context.t("about", "es"), "Acerca de");
assert.equal(context.t("about", "en"), "About");
assert.equal(context.t("about", "es-ES", "en"), "About");
assert.equal(context.t("about", "en_US", "es"), "Acerca de");
assert.equal(context.t("title", "es_ES.UTF-8", "system"), "System Info");
assert.equal(context.t("title", "es", "es"), "System Info");
assert.equal(context.t("title", "en_US", "en"), "System Info");
assert.equal(context.t("uiLanguage", "en", "es"), "Idioma de la interfaz");
assert.equal(context.t("uiLanguageSystem", "en", "es"), "Sistema");
assert.equal(context.t("uiLanguageEn", "es", "system"), "English");
assert.equal(context.t("uiLanguageEs", "es", "system"), "Español");
assert.equal(context.t("openBtop", "es"), "Abrir btop");
delete context.translations.es.openBtop;
assert.equal(context.t("openBtop", "es"), "Open btop");
context.translations.es.openBtop = "Abrir btop";
assert.equal(context.t("unknownKey", "es"), "⟦unknownKey⟧");

const qmlSources = {};
for (const qmlFile of ["BarWidget.qml", "Panel.qml"]) {
  const source = fs.readFileSync(path.join(__dirname, "..", qmlFile), "utf8");
  qmlSources[qmlFile] = source;
  for (const [, key] of source.matchAll(/\.tr\("([^"]+)"\)/g)) {
    assert.ok(Object.hasOwn(context.translations.en, key), `${qmlFile}: missing English key ${key}`);
    assert.ok(Object.hasOwn(context.translations.es, key), `${qmlFile}: missing Spanish key ${key}`);
  }
}

assert.match(qmlSources["BarWidget.qml"], /function setUiLanguage\(language\)/);
assert.match(qmlSources["BarWidget.qml"], /updateEntryInline\(root\.moduleName, entry\)/);
assert.match(qmlSources["Panel.qml"], /hostWidget\.setUiLanguage\(language\)/);
const manifest = JSON.parse(fs.readFileSync(path.join(__dirname, "..", "manifest.json"), "utf8"));
assert.equal(manifest.version, "1.1.0");
assert.equal(manifest.name, "System Info");
assert.equal(manifest.barWidget.displayName, "System Info");
assert.ok(qmlSources["Panel.qml"].includes(`pluginVersion: "${manifest.version}"`));

console.log("PASS: bilingual catalogs, language override/persistence, locale resolution, and fallbacks");
