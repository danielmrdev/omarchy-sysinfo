#!/usr/bin/env node
"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const source = fs.readFileSync(path.join(__dirname, "..", "BarWidget.qml"), "utf8");
assert.match(source, /id: maximumCpuLabel\s+visible: false\s+textFormat: Text\.PlainText\s+text: "100%"/);
assert.match(source, /property real valueSlotWidth: 0/);
assert.match(source, /Math\.max\(metric\.valueSlotWidth, valueLabel\.implicitWidth\)/);
assert.match(source, /valueSlotWidth: maximumCpuLabel\.implicitWidth/);

console.log("PASS: bar reserves width for the three-digit CPU percentage");
