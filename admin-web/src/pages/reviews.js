import { renderReviewsPage } from "./reviewsPage.js";

export function registerReviewsPage(reg) {
  if (typeof reg !== "function") return;
  reg("reviews", async (el, ctx) => {
    return await renderReviewsPage(el, ctx);
  });
}
