"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

function matchingBrace(source, openingBrace) {
  let depth = 0;
  let quote = "";
  let escaped = false;
  let lineComment = false;
  let blockComment = false;

  for (let index = openingBrace; index < source.length; index += 1) {
    const current = source[index];
    const next = source[index + 1] || "";

    if (lineComment) {
      if (current === "\n") lineComment = false;
      continue;
    }
    if (blockComment) {
      if (current === "*" && next === "/") {
        blockComment = false;
        index += 1;
      }
      continue;
    }
    if (quote) {
      if (escaped) escaped = false;
      else if (current === "\\") escaped = true;
      else if (current === quote) quote = "";
      continue;
    }
    if (current === "/" && next === "/") {
      lineComment = true;
      index += 1;
      continue;
    }
    if (current === "/" && next === "*") {
      blockComment = true;
      index += 1;
      continue;
    }
    if (current === "\"" || current === "'") {
      quote = current;
      continue;
    }
    if (current === "{") depth += 1;
    else if (current === "}") {
      depth -= 1;
      if (depth === 0) return index;
    }
  }

  throw new Error(`Unmatched QML brace at offset ${openingBrace}`);
}

const repoDir = path.join(__dirname, "..");
const qmlFiles = ["OmaSys.qml", "BarWidget.qml"];
let textSinkCount = 0;

for (const filename of qmlFiles) {
  const source = fs.readFileSync(path.join(repoDir, filename), "utf8");
  const textComponent = /\bText\s*\{/g;
  let match;

  while ((match = textComponent.exec(source)) !== null) {
    const openingBrace = source.indexOf("{", match.index);
    const closingBrace = matchingBrace(source, openingBrace);
    const block = source.slice(openingBrace, closingBrace + 1);
    const line = source.slice(0, match.index).split("\n").length;
    assert.match(
      block,
      /\btextFormat\s*:\s*Text\.PlainText\b/,
      `${filename}:${line} must force Text.PlainText`
    );
    textSinkCount += 1;
    textComponent.lastIndex = closingBrace + 1;
  }
}

assert.ok(textSinkCount > 0, "Expected to inspect at least one QML Text sink");

const panelSource = fs.readFileSync(path.join(repoDir, "OmaSys.qml"), "utf8");
assert.match(panelSource, /^\s*SafeConfirmDialog\s*\{/m);
assert.doesNotMatch(panelSource, /^\s*ConfirmDialog\s*\{/m);

process.stdout.write(`QML security tests passed (${textSinkCount} plain-text sinks)\n`);
