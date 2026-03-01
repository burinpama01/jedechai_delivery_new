import { renderDriversPage } from "./driversPage.js";

export function registerDriversPage(reg) {
  if (typeof reg !== "function") return;
  reg("drivers", async (el, ctx) => {
    return await renderDriversPage(el, ctx);
  });
}
