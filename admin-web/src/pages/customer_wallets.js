import { renderCustomerWalletsPage } from "./customerWalletsPage.js";

export function registerCustomerWalletsPage(reg) {
  if (typeof reg !== "function") return;
  reg("customer_wallets", async (el, ctx) => {
    return await renderCustomerWalletsPage(el, ctx);
  });
}
