const channel = "roGardenMarketBridge";
const officialUrl = "https://event.gnjoy.com.tw/RoZ/RoZ_ShopSearch";
let officialTabId = null;
let activeJob = null;
const jobQueue = [];

function deliver(tabId, message) {
  chrome.tabs.sendMessage(tabId, { channel, ...message }).catch(() => {});
}

function startLookup(tabId, job, attempts = 0) {
  chrome.tabs.sendMessage(tabId, { type: "performLookup", ...job }).catch(() => {
    if (attempts < 12) setTimeout(() => startLookup(tabId, job, attempts + 1), 500);
    else finishJob({ ok: false, error: "官方露天查價頁沒有回應。" });
  });
}

async function getOfficialTab() {
  if (officialTabId != null) {
    try { return await chrome.tabs.get(officialTabId); } catch { officialTabId = null; }
  }
  const existing = await chrome.tabs.query({ url: "https://event.gnjoy.com.tw/RoZ/RoZ_ShopSearch*" });
  if (existing[0]) {
    officialTabId = existing[0].id;
    return existing[0];
  }
  const created = await chrome.tabs.create({ url: officialUrl, active: false });
  officialTabId = created.id;
  return created;
}

async function processQueue() {
  if (activeJob || jobQueue.length === 0) return;
  activeJob = jobQueue.shift();
  try {
    const tab = await getOfficialTab();
    startLookup(tab.id, activeJob);
  } catch {
    finishJob({ ok: false, error: "無法開啟官方露天查價頁。" });
  }
}

function finishJob(result) {
  if (!activeJob) return;
  const job = activeJob;
  activeJob = null;
  if (result.requiresAttention && officialTabId != null) chrome.tabs.update(officialTabId, { active: true }).catch(() => {});
  deliver(job.siteTabId, { type: "result", name: job.name, ok: result.ok, lowest: result.lowest, second: result.second, buyingHighest: result.buyingHighest, buyingSecond: result.buyingSecond, sellingUnavailable: result.sellingUnavailable, buyingUnavailable: result.buyingUnavailable, unavailable: result.unavailable, checkedAt: result.checkedAt, error: result.error });
  setTimeout(processQueue, 150);
}

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message?.type === "lookup" && sender.tab?.id) {
    const job = { requestId: message.requestId, name: message.name, officialName: message.officialName || message.name, server: message.server, siteTabId: sender.tab.id };
    jobQueue.push(job);
    processQueue();
    sendResponse({ accepted: true });
    return;
  }

  if (message?.type === "lookupResult") {
    if (!activeJob || activeJob.requestId !== message.requestId) return;
    finishJob(message);
  }
});

chrome.tabs.onRemoved.addListener(tabId => {
  if (tabId === officialTabId) officialTabId = null;
});
