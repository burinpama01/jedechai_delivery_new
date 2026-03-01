import { renderPromosPage } from "./promosPage.js";

export function registerPromosPage(reg) {
  if (typeof reg !== "function") return;
  reg("promos", async (el, ctx) => {
    return await renderPromosPage(el, ctx);
  });
}
