import { renderDashboardPage } from "./dashboardPage.js";

export function registerDashboardPage(reg) {
  if (typeof reg !== "function") return;
  reg("dashboard", async (el, ctx) => {
    return await renderDashboardPage(el, ctx);
  });
}
