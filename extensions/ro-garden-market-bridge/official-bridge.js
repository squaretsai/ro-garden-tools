const sleep = milliseconds => new Promise(resolve => setTimeout(resolve, milliseconds));

function selectOption(triggerId, matchText) {
  const trigger = document.getElementById(triggerId);
  if (!trigger) return false;
  if (trigger.textContent.includes(matchText)) return true;
  trigger.click();
  const option = [...document.querySelectorAll("li")].find(element => element.textContent.trim() === matchText);
  if (!option) return false;
  option.click();
  return trigger.textContent.includes(matchText);
}

function pricesFromRows(expectedName) {
  return [...document.querySelectorAll("#_tbody tr")]
    .map(row => ({
      price: Number((row.querySelector(".price span")?.textContent || "").replace(/[^0-9]/g, "")),
      kind: row.querySelector(".buySell span")?.textContent.trim(),
      name: row.querySelector(".itemName")?.textContent.trim()
    }))
    .filter(item => item.name === expectedName && item.kind === "販售" && Number.isFinite(item.price) && item.price > 0)
    .sort((left, right) => left.price - right.price);
}

function isVisible(selector) {
  const element = document.querySelector(selector);
  return Boolean(element && getComputedStyle(element).display !== "none" && getComputedStyle(element).visibility !== "hidden");
}

async function performLookup(job) {
  const serverName = job.server === "629" ? "艾克瑟" : "西格倫";
  if (!selectOption("div_svr", serverName)) return { ok: false, error: `官方頁無法切換到「${serverName}」。` };
  if (!selectOption("div_storetype", "販售")) return { ok: false, error: "官方頁無法切換到「販售」查詢。" };

  const input = document.getElementById("txb_KeyWord");
  const button = document.getElementById("searchBtn");
  if (!input || !button) return { ok: false, error: "官方查價頁版面已變更，請更新橋接擴充功能。" };

  const officialName = job.officialName || job.name;
  input.value = `"${officialName}"`;
  input.dispatchEvent(new Event("input", { bubbles: true }));
  input.dispatchEvent(new Event("change", { bubbles: true }));
  button.click();

  for (let attempt = 0; attempt < 30; attempt += 1) {
    await sleep(700);
    const prices = pricesFromRows(officialName);
    if (prices.length >= 1) return { ok: true, lowest: prices[0].price, second: prices[1]?.price ?? null, checkedAt: new Date().toISOString() };
    const text = document.body.innerText;
    if (/請先登入|圖形驗證/.test(text)) return { ok: false, requiresAttention: true, error: "請先在官方分頁登入或完成人機驗證，然後回本頁再按一次查詢。" };
    if (isVisible("#PoringCry1")) return { ok: true, unavailable: true, lowest: null, second: null, checkedAt: new Date().toISOString() };
  }
  return { ok: false, error: "官方查詢逾時或找不到販售資料。" };
}

chrome.runtime.onMessage.addListener(message => {
  if (message?.type !== "performLookup") return;
  performLookup(message).then(result => {
    chrome.runtime.sendMessage({ type: "lookupResult", requestId: message.requestId, ...result });
  }).catch(() => {
    chrome.runtime.sendMessage({ type: "lookupResult", requestId: message.requestId, ok: false, error: "讀取官方查價結果時發生錯誤。" });
  });
});
