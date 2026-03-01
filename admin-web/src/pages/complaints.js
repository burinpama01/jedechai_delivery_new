import { renderComplaintsPage } from "./complaintsPage.js";

export function registerComplaintsPage(reg) {
  if (typeof reg !== "function") return;
  reg("complaints", async (el, ctx) => {
    return await renderComplaintsPage(el, ctx);
  });
}
