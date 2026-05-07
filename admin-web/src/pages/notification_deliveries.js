import { renderNotificationDeliveriesPage } from "./notificationDeliveriesPage.js";

export function registerNotificationDeliveriesPage(reg) {
  if (typeof reg !== "function") return;
  reg("notification_deliveries", async (el, ctx) => {
    return await renderNotificationDeliveriesPage(el, ctx);
  });
}
