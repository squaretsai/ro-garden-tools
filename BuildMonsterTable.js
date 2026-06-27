const fs = require("fs");

const sourceUrl = "https://assets.twroz.wiki/monsters_display_index.json";
const data = JSON.parse(fs.readFileSync("monster-db-full.json", "utf8"));

function numberOrBlank(value) {
  const number = Number(value);
  return Number.isFinite(number) ? number : "";
}

function ratio(exp, hp) {
  const expNumber = Number(exp);
  const hpNumber = Number(hp);

  if (!Number.isFinite(expNumber) || !Number.isFinite(hpNumber) || hpNumber <= 0) {
    return "";
  }

  return Number((expNumber / hpNumber).toFixed(4));
}

function csvEscape(value) {
  const text = String(value ?? "");
  return /[",\r\n]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
}

function monsterDetailUrl(monster) {
  return `https://twroz.wiki/mob?search_query=${encodeURIComponent(String(monster.id))}`;
}

function getMaps(monster) {
  const seen = new Set();
  const maps = [];

  for (const spawn of monster.spawns || []) {
    const mapName = spawn.map_name || "";
    const description = spawn.description || "";
    const label = description && mapName ? `${description} (${mapName})` : description || mapName;

    if (label && !seen.has(label)) {
      seen.add(label);
      maps.push(label);
    }
  }

  return maps.join("；");
}

const rows = Object.values(data)
  .map((monster) => {
    const hp = numberOrBlank(monster.stats?.hp);
    const baseExp = numberOrBlank(monster.stats?.exp?.base);
    const jobExp = numberOrBlank(monster.stats?.exp?.job);
    const elementType = monster.basic_info?.element?.type || "";
    const elementLevel = monster.basic_info?.element?.level || "";
    const element = elementType && elementLevel ? `${elementType}${elementLevel}` : elementType;

    return {
      "魔物名稱": monster.name?.zh_tw || monster.name?.en || String(monster.id),
      "等級": numberOrBlank(monster.basic_info?.level),
      "血量": hp,
      "95%迴避": numberOrBlank(monster.stats?.flee_95_percent),
      "100%命中": numberOrBlank(monster.stats?.hit_100_percent),
      "屬性": element,
      "種族": monster.basic_info?.race || "",
      "體型": monster.basic_info?.size || "",
      "base經驗血量比(經驗值/血量)": ratio(baseExp, hp),
      "job經驗血量比": ratio(jobExp, hp),
      "所屬地圖": getMaps(monster),
      "魔物詳細資料": monsterDetailUrl(monster)
    };
  })
  .sort((a, b) => String(a["魔物名稱"]).localeCompare(String(b["魔物名稱"]), "zh-TW"));

const columns = [
  "魔物名稱",
  "等級",
  "血量",
  "95%迴避",
  "100%命中",
  "屬性",
  "種族",
  "體型",
  "base經驗血量比(經驗值/血量)",
  "job經驗血量比",
  "所屬地圖",
  "魔物詳細資料"
];

const filterableColumns = columns
  .map((column, index) => ({ column, index }))
  .filter(({ column }) => column !== "魔物詳細資料");

const csv = [
  columns.map(csvEscape).join(","),
  ...rows.map((row) => columns.map((column) => csvEscape(row[column])).join(","))
].join("\r\n");

fs.writeFileSync("monster-stat-table.csv", `\uFEFF${csv}\r\n`, "utf8");

const html = `<!doctype html>
<html lang="zh-Hant">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>RO樂園魔物命中迴避表</title>
  <style>
    :root {
      --bg: #f6f3ee;
      --paper: #fffdf9;
      --ink: #202329;
      --muted: #69707d;
      --line: #ddd5ca;
      --accent: #a5282d;
      --header: #efe6da;
    }

    * { box-sizing: border-box; }

    body {
      margin: 0;
      background: var(--bg);
      color: var(--ink);
      font-family: "Microsoft JhengHei", "Noto Sans TC", system-ui, sans-serif;
    }

    main {
      width: min(1440px, calc(100% - 28px));
      margin: 0 auto;
      padding: 24px 0 36px;
    }

    header {
      display: flex;
      align-items: end;
      justify-content: space-between;
      gap: 16px;
      margin-bottom: 16px;
    }

    h1 {
      margin: 0;
      font-size: 28px;
      line-height: 1.2;
    }

    .meta {
      margin-top: 6px;
      color: var(--muted);
      font-size: 13px;
    }

    .toolbar {
      display: flex;
      gap: 10px;
      align-items: center;
      flex-wrap: wrap;
      margin-bottom: 12px;
    }

    .filterbar {
      display: grid;
      grid-template-columns: minmax(160px, 1.15fr) minmax(120px, 0.8fr) minmax(160px, 1fr) auto auto;
      gap: 10px;
      align-items: center;
      margin-bottom: 12px;
      padding: 12px;
      border: 1px solid var(--line);
      border-radius: 8px;
      background: rgba(255, 253, 249, 0.72);
    }

    .active-filters {
      display: flex;
      gap: 8px;
      flex-wrap: wrap;
      margin-bottom: 12px;
      min-height: 30px;
    }

    input,
    select,
    button {
      font: inherit;
    }

    input,
    select {
      width: min(420px, 100%);
      height: 42px;
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 8px 12px;
      font: inherit;
      background: var(--paper);
    }

    select {
      width: 100%;
    }

    button,
    a.button {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      height: 42px;
      padding: 8px 12px;
      border: 1px solid transparent;
      border-radius: 8px;
      background: var(--accent);
      color: #fff;
      text-decoration: none;
      font-weight: 800;
      font-size: 14px;
      cursor: pointer;
      white-space: nowrap;
    }

    button.secondary {
      border-color: var(--line);
      background: var(--paper);
      color: var(--ink);
    }

    .filter-chip {
      display: inline-flex;
      align-items: center;
      gap: 7px;
      min-height: 30px;
      padding: 5px 8px;
      border: 1px solid var(--line);
      border-radius: 8px;
      background: var(--paper);
      color: var(--ink);
      font-size: 13px;
      font-weight: 700;
    }

    .toggle-filter {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      min-height: 42px;
      padding: 8px 10px;
      border: 1px solid var(--line);
      border-radius: 8px;
      background: var(--paper);
      color: var(--ink);
      font-size: 14px;
      font-weight: 800;
    }

    .toggle-filter input {
      width: 18px;
      height: 18px;
      accent-color: var(--accent);
    }

    .filter-chip button {
      width: 22px;
      height: 22px;
      padding: 0;
      border-radius: 50%;
      background: #efe6da;
      color: var(--accent);
      font-size: 14px;
      line-height: 1;
    }

    .table-wrap {
      border: 1px solid var(--line);
      border-radius: 8px;
      overflow: auto;
      background: var(--paper);
      max-height: calc(100vh - 150px);
    }

    table {
      border-collapse: collapse;
      width: 100%;
      min-width: 1240px;
      font-size: 13px;
    }

    th,
    td {
      border-bottom: 1px solid var(--line);
      padding: 8px 10px;
      vertical-align: top;
      text-align: left;
    }

    th {
      position: sticky;
      top: 0;
      z-index: 1;
      background: var(--header);
      cursor: pointer;
      white-space: nowrap;
      font-weight: 900;
    }

    td.num {
      text-align: right;
      font-variant-numeric: tabular-nums;
      white-space: nowrap;
    }

    td.maps {
      min-width: 260px;
      color: #3f4650;
      line-height: 1.45;
    }

    td.detail {
      min-width: 116px;
      text-align: center;
      white-space: nowrap;
    }

    .detail-link {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      min-height: 30px;
      padding: 5px 10px;
      border: 1px solid rgba(165, 40, 45, 0.22);
      border-radius: 8px;
      background: #fff6ea;
      color: var(--accent);
      text-decoration: none;
      font-size: 13px;
      font-weight: 900;
    }

    .detail-link:hover,
    .detail-link:focus-visible {
      border-color: var(--accent);
      outline: none;
    }

    details.map-list {
      max-width: 420px;
    }

    details.map-list summary {
      display: inline-flex;
      align-items: center;
      min-height: 30px;
      padding: 5px 9px;
      border: 1px solid var(--line);
      border-radius: 8px;
      background: #fffdf9;
      color: var(--accent);
      cursor: pointer;
      font-weight: 800;
      list-style: none;
      white-space: nowrap;
    }

    details.map-list summary::-webkit-details-marker {
      display: none;
    }

    details.map-list summary::before {
      content: "+";
      display: inline-grid;
      place-items: center;
      width: 18px;
      height: 18px;
      margin-right: 6px;
      border-radius: 50%;
      background: var(--accent);
      color: #fff;
      font-size: 12px;
      line-height: 1;
    }

    details.map-list[open] summary::before {
      content: "-";
    }

    .map-content {
      margin-top: 8px;
      color: #3f4650;
      line-height: 1.55;
      white-space: normal;
    }

    tr:hover td {
      background: #fbf7f0;
    }

    @media (max-width: 720px) {
      header {
        align-items: flex-start;
        flex-direction: column;
      }

      .filterbar {
        grid-template-columns: 1fr;
      }
    }
  </style>
</head>
<body>
  <main>
    <header>
      <div>
        <h1>RO樂園魔物命中迴避表</h1>
        <div class="meta">資料來源：${sourceUrl}，共 ${rows.length} 筆。點欄位標題可排序。</div>
      </div>
      <a class="button" href="monster-stat-table.csv" download>下載 CSV</a>
    </header>

    <div class="toolbar">
      <input id="search" type="search" placeholder="搜尋魔物、屬性、種族、地圖...">
      <label class="toggle-filter">
        <input id="excludeElite" type="checkbox">
        排除菁英怪
      </label>
      <span class="meta" id="count">${rows.length} 筆</span>
    </div>

    <div class="filterbar" aria-label="欄位篩選器">
      <select id="filterColumn" aria-label="篩選欄位">
        ${filterableColumns.map(({ column, index }) => `<option value="${index}">${column}</option>`).join("")}
      </select>
      <select id="filterOperator" aria-label="篩選條件"></select>
      <input id="filterValue" type="text" placeholder="輸入篩選值，例如 0.6、火、人形">
      <button type="button" id="addFilter">加入篩選</button>
      <button type="button" class="secondary" id="clearFilters">清除全部</button>
    </div>

    <div class="active-filters" id="activeFilters" aria-live="polite"></div>

    <div class="table-wrap">
      <table id="monsterTable">
        <thead>
          <tr>${columns.map((column, index) => `<th data-index="${index}">${column}</th>`).join("")}</tr>
        </thead>
        <tbody>
          ${rows.map((row) => `<tr>${columns.map((column) => {
            const value = row[column] ?? "";
            const escaped = String(value).replace(/[&<>"']/g, (char) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[char]));
            const className = column.includes("比") || column.includes("迴避") || column.includes("命中") || column === "等級" || column === "血量" ? "num" : column === "所屬地圖" ? "maps" : column === "魔物詳細資料" ? "detail" : "";

            if (column === "所屬地圖") {
              const mapCount = value ? String(value).split("；").filter(Boolean).length : 0;
              const label = mapCount ? `展開地圖 (${mapCount})` : "無地圖資料";
              return `<td class="${className}"><details class="map-list"><summary>${label}</summary><div class="map-content">${escaped || "無地圖資料"}</div></details></td>`;
            }

            if (column === "魔物詳細資料") {
              return `<td class="${className}"><a class="detail-link" href="${escaped}" target="_blank" rel="noreferrer">打開</a></td>`;
            }

            return `<td class="${className}">${escaped}</td>`;
          }).join("")}</tr>`).join("")}
        </tbody>
      </table>
    </div>
  </main>

  <script>
    const table = document.getElementById("monsterTable");
    const tbody = table.tBodies[0];
    const search = document.getElementById("search");
    const excludeElite = document.getElementById("excludeElite");
    const count = document.getElementById("count");
    const filterColumn = document.getElementById("filterColumn");
    const filterOperator = document.getElementById("filterOperator");
    const filterValue = document.getElementById("filterValue");
    const addFilter = document.getElementById("addFilter");
    const clearFilters = document.getElementById("clearFilters");
    const activeFilters = document.getElementById("activeFilters");
    const columns = ${JSON.stringify(columns)};
    const numericColumnIndexes = new Set(${JSON.stringify(columns.map((column, index) => (column.includes("比") || column.includes("迴避") || column.includes("命中") || column === "等級" || column === "血量") ? index : null).filter((index) => index !== null))});
    const operators = {
      numeric: [
        ["lte", "小於等於"],
        ["gte", "大於等於"],
        ["lt", "小於"],
        ["gt", "大於"],
        ["eq", "等於"],
        ["neq", "不等於"]
      ],
      text: [
        ["contains", "包含"],
        ["not_contains", "不包含"],
        ["eq", "等於"],
        ["neq", "不等於"]
      ]
    };
    let filters = [];
    let sortState = { index: 0, direction: 1 };

    function normalize(value) {
      return String(value || "").toLowerCase().replace(/\\s+/g, "");
    }

    function isNumericColumn(index) {
      return numericColumnIndexes.has(Number(index));
    }

    function getCellText(row, index) {
      const mapContent = row.cells[index].querySelector(".map-content");
      return (mapContent || row.cells[index]).textContent.trim();
    }

    function isEliteMonster(row) {
      return /^(菁英|憤怒|雄壯|迅捷|狡猾)/.test(getCellText(row, 0));
    }

    function getCellNumber(row, index) {
      const text = getCellText(row, index);
      const number = Number(text);
      return Number.isFinite(number) && text !== "" ? number : null;
    }

    function refreshOperatorOptions() {
      const type = isNumericColumn(filterColumn.value) ? "numeric" : "text";
      filterOperator.innerHTML = "";

      for (const [value, label] of operators[type]) {
        const option = document.createElement("option");
        option.value = value;
        option.textContent = label;
        filterOperator.appendChild(option);
      }

      filterValue.placeholder = type === "numeric" ? "輸入數字，例如 0.6、80、300" : "輸入文字，例如 火、人形、小";
    }

    function matchesFilter(row, filter) {
      if (filter.type === "numeric") {
        const cell = getCellNumber(row, filter.index);

        if (cell === null) {
          return false;
        }

        if (filter.operator === "lte") return cell <= filter.numberValue;
        if (filter.operator === "gte") return cell >= filter.numberValue;
        if (filter.operator === "lt") return cell < filter.numberValue;
        if (filter.operator === "gt") return cell > filter.numberValue;
        if (filter.operator === "eq") return cell === filter.numberValue;
        if (filter.operator === "neq") return cell !== filter.numberValue;
      }

      const cell = normalize(getCellText(row, filter.index));
      const value = normalize(filter.value);

      if (filter.operator === "contains") return cell.includes(value);
      if (filter.operator === "not_contains") return !cell.includes(value);
      if (filter.operator === "eq") return cell === value;
      if (filter.operator === "neq") return cell !== value;

      return true;
    }

    function updateFilter() {
      const query = normalize(search.value);
      let visible = 0;

      for (const row of tbody.rows) {
        const matchSearch = !query || normalize(row.innerText).includes(query);
        const matchFilters = filters.every((filter) => matchesFilter(row, filter));
        const matchElite = !excludeElite.checked || !isEliteMonster(row);
        const match = matchSearch && matchFilters && matchElite;
        row.hidden = !match;
        if (match) visible += 1;
      }

      count.textContent = visible + " 筆";
    }

    function renderFilters() {
      activeFilters.innerHTML = "";

      for (const filter of filters) {
        const chip = document.createElement("span");
        const remove = document.createElement("button");

        chip.className = "filter-chip";
        chip.textContent = columns[filter.index] + " " + filter.label + " " + filter.value;
        remove.type = "button";
        remove.textContent = "×";
        remove.title = "移除篩選";
        remove.addEventListener("click", () => {
          filters = filters.filter((item) => item.id !== filter.id);
          renderFilters();
          updateFilter();
        });
        chip.appendChild(remove);
        activeFilters.appendChild(chip);
      }
    }

    function addCurrentFilter() {
      const index = Number(filterColumn.value);
      const value = filterValue.value.trim();

      if (!value) {
        filterValue.focus();
        return;
      }

      const type = isNumericColumn(index) ? "numeric" : "text";
      const operator = filterOperator.value;
      const label = (operators[type].find(([op]) => op === operator) || [operator, operator])[1];
      const numberValue = Number(value);

      if (type === "numeric" && !Number.isFinite(numberValue)) {
        filterValue.focus();
        return;
      }

      filters.push({
        id: Date.now() + Math.random(),
        index,
        type,
        operator,
        label,
        value,
        numberValue
      });
      filterValue.value = "";
      renderFilters();
      updateFilter();
    }

    function cellValue(row, index) {
      const text = getCellText(row, index);
      const number = Number(text);
      return Number.isFinite(number) && text !== "" ? number : text;
    }

    table.tHead.addEventListener("click", (event) => {
      const th = event.target.closest("th");
      if (!th) return;

      const index = Number(th.dataset.index);
      sortState.direction = sortState.index === index ? sortState.direction * -1 : 1;
      sortState.index = index;

      const rowsToSort = Array.from(tbody.rows);
      rowsToSort.sort((a, b) => {
        const av = cellValue(a, index);
        const bv = cellValue(b, index);

        if (typeof av === "number" && typeof bv === "number") {
          return (av - bv) * sortState.direction;
        }

        return String(av).localeCompare(String(bv), "zh-TW") * sortState.direction;
      });

      tbody.append(...rowsToSort);
      updateFilter();
    });

    search.addEventListener("input", updateFilter);
    excludeElite.addEventListener("change", updateFilter);
    filterColumn.addEventListener("change", refreshOperatorOptions);
    addFilter.addEventListener("click", addCurrentFilter);
    clearFilters.addEventListener("click", () => {
      filters = [];
      renderFilters();
      updateFilter();
    });
    filterValue.addEventListener("keydown", (event) => {
      if (event.key === "Enter") {
        event.preventDefault();
        addCurrentFilter();
      }
    });
    refreshOperatorOptions();
  </script>
</body>
</html>
`;

fs.writeFileSync("monster-stat-table.html", html, "utf8");

console.log(JSON.stringify({
  rows: rows.length,
  csv: "monster-stat-table.csv",
  html: "monster-stat-table.html"
}, null, 2));
