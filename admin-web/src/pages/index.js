// Central page registry — imports each page's renderer directly.
// (เดิมมี stub ไฟล์ละ 8 บรรทัดคั่นกลาง 21 ไฟล์ — ยุบเข้าไฟล์นี้ 2026-07-18)
import { renderDashboardPage } from "./dashboardPage.js";
import { renderOrdersPage } from "./ordersPage.js";
import { renderPendingOrdersPage, disposePendingOrdersPage } from "./pendingOrdersPage.js";
import { renderMapPage, disposeMapPage } from "./mapPage.js";
import { renderSettingsPage } from "./settingsPage.js";
import { renderAccountDeletionsPage } from "./accountDeletionsPage.js";
import { renderUsersPage } from "./usersPage.js";
import { renderDriversPage } from "./driversPage.js";
import { renderMerchantsPage } from "./merchantsPage.js";
import { renderPromosPage } from "./promosPage.js";
import { renderWithdrawalsPage } from "./withdrawalsPage.js";
import { renderTopupsPage } from "./topupsPage.js";
import { renderCustomerWalletsPage } from "./customerWalletsPage.js";
import { renderLaundryPage } from "./laundryPage.js";
import { renderMenusPage } from "./menusPage.js";
import { renderRevenuePage } from "./revenuePage.js";
import { renderComplaintsPage } from "./complaintsPage.js";
import { renderReferralsPage } from "./referralsPage.js";
import { renderNotificationDeliveriesPage } from "./notificationDeliveriesPage.js";
import { renderReviewsPage } from "./reviewsPage.js";
import { renderBroadcastPage } from "./broadcastPage.js";
import { renderShopStoresPage } from "./shopStoresPage.js";

export function registerInitialPages(reg) {
  if (typeof reg !== "function") return;

  const pages = [
    ["dashboard", renderDashboardPage],
    ["orders", renderOrdersPage],
    ["pending_orders", renderPendingOrdersPage, disposePendingOrdersPage],
    ["map", renderMapPage, disposeMapPage],
    ["settings", renderSettingsPage],
    ["account_deletions", renderAccountDeletionsPage],
    ["users", renderUsersPage],
    ["drivers", renderDriversPage],
    ["merchants", renderMerchantsPage],
    ["promos", renderPromosPage],
    ["withdrawals", renderWithdrawalsPage],
    ["topups", renderTopupsPage],
    ["customer_wallets", renderCustomerWalletsPage],
    ["laundry", renderLaundryPage],
    ["menus", renderMenusPage],
    ["revenue", renderRevenuePage],
    ["complaints", renderComplaintsPage],
    ["referrals", renderReferralsPage],
    ["notification_deliveries", renderNotificationDeliveriesPage],
    ["reviews", renderReviewsPage],
    ["broadcast", renderBroadcastPage],
    ["shop_stores", renderShopStoresPage],
  ];

  for (const [name, renderer, dispose] of pages) {
    const opts = typeof dispose === "function"
      ? { dispose: async (ctx) => await dispose(ctx) }
      : undefined;
    reg(name, async (el, ctx) => await renderer(el, ctx), opts);
  }
}
