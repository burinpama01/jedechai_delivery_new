import { renderTopupsPage } from "./topupsPage.js";

export function registerTopupsPage(reg) {
  if (typeof reg !== "function") return;
  reg("topups", async (el, ctx) => {
    return await renderTopupsPage(el, ctx);
  });
}
