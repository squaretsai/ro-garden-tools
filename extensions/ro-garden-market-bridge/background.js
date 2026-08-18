const channel = "roGardenMarketBridge";
const officialUrl = "https://event.gnjoy.com.tw/RoZ/RoZ_ShopSearch";
const jobs = new Map();

function deliver(tabId, message) {
  chrome.tabs.sendMessage(tabId, { channel, ...message }).catch(() => {});
}

function startLookup(tabId, job, attempts = 0) {
  chrome.tabs.sendMessage(tabId, { type: "performLookup", ...job }).catch(() => {
    if (attempts < 12) setTimeout(() => startLookup(tabId, job, attempts + 1), 500);
  });
}

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message?.type === "lookup" && sender.tab?.id) {
    const job = { requestId: message.requestId, name: message.name, server: message.server, siteTabId: sender.tab.id };
    chrome.tabs.create({ url: officialUrl, active: true }).then(tab => {
      jobs.set(job.requestId, { ...job, officialTabId: tab.id });
      startLookup(tab.id, job);
    }).catch(() => {
      deliver(job.siteTabId, { type: "result", name: job.name, ok: false, error: "無法開啟官方露天查價頁。" });
    });
    sendResponse({ accepted: true });
    return;
  }

  if (message?.type === "lookupResult") {
    const job = jobs.get(message.requestId);
    if (!job) return;
    deliver(job.siteTabId, { type: "result", name: job.name, ok: message.ok, lowest: message.lowest, second: message.second, checkedAt: message.checkedAt, error: message.error });
    jobs.delete(message.requestId);
  }
});
