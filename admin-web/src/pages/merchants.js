import { renderMerchantsPage } from "./merchantsPage.js";

export function registerMerchantsPage(reg) {
  if (typeof reg !== "function") return;
  reg("merchants", async (el, ctx) => {
    return await renderMerchantsPage(el, ctx);
  });
}
