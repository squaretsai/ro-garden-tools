const channel = "roGardenMarketBridge";
const pageOrigin = "https://squaretsai.github.io";

window.addEventListener("message", event => {
  if (event.source !== window || event.origin !== pageOrigin) return;
  const message = event.data;
  if (!message || message.channel !== channel || message.type !== "lookup") return;
  chrome.runtime.sendMessage({ type: "lookup", ...message }, response => {
    if (chrome.runtime.lastError) {
      window.postMessage({ channel, type: "result", name: message.name, ok: false, error: "市價橋接擴充功能沒有回應，請重新整理本頁後再試。" }, pageOrigin);
      return;
    }
    if (response?.accepted) {
      window.postMessage({ channel, type: "accepted", name: message.name }, pageOrigin);
    }
  });
});

chrome.runtime.onMessage.addListener(message => {
  if (!message || message.channel !== channel || message.type !== "result") return;
  window.postMessage(message, pageOrigin);
});
