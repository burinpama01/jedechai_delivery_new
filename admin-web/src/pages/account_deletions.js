import { renderAccountDeletionsPage } from "./accountDeletionsPage.js";

export function registerAccountDeletionsPage(reg) {
  if (typeof reg !== "function") return;
  reg("account_deletions", async (el, ctx) => {
    return await renderAccountDeletionsPage(el, ctx);
  });
}
