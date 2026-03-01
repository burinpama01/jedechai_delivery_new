import { renderRevenuePage } from "./revenuePage.js";

export function registerRevenuePage(reg) {
  if (typeof reg !== "function") return;
  reg("revenue", async (el, ctx) => {
    return await renderRevenuePage(el, ctx);
  });
}
