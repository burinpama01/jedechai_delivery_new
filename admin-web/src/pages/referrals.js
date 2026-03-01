import { renderReferralsPage } from "./referralsPage.js";

export function registerReferralsPage(reg) {
  if (typeof reg !== "function") return;
  reg("referrals", async (el, ctx) => {
    return await renderReferralsPage(el, ctx);
  });
}
