import { renderWithdrawalsPage } from "./withdrawalsPage.js";

export function registerWithdrawalsPage(reg) {
  if (typeof reg !== "function") return;
  reg("withdrawals", async (el, ctx) => {
    return await renderWithdrawalsPage(el, ctx);
  });
}
