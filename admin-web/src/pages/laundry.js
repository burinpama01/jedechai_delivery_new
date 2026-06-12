import { renderLaundryPage } from "./laundryPage.js";

export function registerLaundryPage(reg) {
  if (typeof reg !== "function") return;
  reg("laundry", async (el, ctx) => {
    return await renderLaundryPage(el, ctx);
  });
}
