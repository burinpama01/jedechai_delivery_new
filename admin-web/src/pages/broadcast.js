import { renderBroadcastPage } from "./broadcastPage.js";

export function registerBroadcastPage(reg) {
  if (typeof reg !== "function") return;
  reg("broadcast", async (el, ctx) => {
    return await renderBroadcastPage(el, ctx);
  });
}
