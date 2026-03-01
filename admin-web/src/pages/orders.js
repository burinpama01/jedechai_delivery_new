import { renderOrdersPage } from "./ordersPage.js";

export function registerOrdersPage(reg) {
  if (typeof reg !== "function") return;
  reg("orders", async (el, ctx) => {
    return await renderOrdersPage(el, ctx);
  });
}
