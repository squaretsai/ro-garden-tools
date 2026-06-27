$ErrorActionPreference = "Stop"

$node = "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe"
$source = "https://assets.twroz.wiki/monsters_display_index.json"
$script = @'
const fs = require("fs");

const source = "https://assets.twroz.wiki/monsters_display_index.json";

function numberOrNull(value) {
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

fetch(source)
  .then((response) => {
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }

    return response.json();
  })
  .then((data) => {
    const fullJson = `${JSON.stringify(data, null, 2)}\n`;
    fs.writeFileSync("monster-db-full.json", fullJson, "utf8");
    fs.writeFileSync("monster-db-full.js", `window.RO_MONSTER_DB_FULL = ${JSON.stringify(data)};\n`, "utf8");

    const light = Object.values(data)
      .map((monster) => {
        const hit100 = numberOrNull(monster.stats?.hit_100_percent);
        const flee95 = numberOrNull(monster.stats?.flee_95_percent);

        return {
          id: monster.id,
          name: monster.name?.zh_tw || monster.name?.en || String(monster.id),
          en: monster.name?.en || "",
          level: numberOrNull(monster.basic_info?.level) ?? "",
          hit100,
          flee95
        };
      })
      .filter((monster) => monster.hit100 !== null || monster.flee95 !== null)
      .sort((a, b) => String(a.name).localeCompare(String(b.name), "zh-TW"));

    fs.writeFileSync("monster-db.js", `window.RO_MONSTER_DB = ${JSON.stringify(light)};\n`, "utf8");

    const meta = {
      source,
      fetchedAt: new Date().toISOString(),
      fullCount: Object.keys(data).length,
      lightCount: light.length,
      files: ["monster-db-full.json", "monster-db-full.js", "monster-db.js"]
    };

    fs.writeFileSync("monster-db.meta.json", `${JSON.stringify(meta, null, 2)}\n`, "utf8");
    console.log(JSON.stringify(meta, null, 2));
  });
'@

if (-not (Test-Path -LiteralPath $node)) {
  throw "找不到 Node.js：$node"
}

Set-Location -LiteralPath $PSScriptRoot
$script | & $node -
