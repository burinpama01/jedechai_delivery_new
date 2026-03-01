import { registerDashboardPage } from "./dashboard.js";
import { registerOrdersPage } from "./orders.js";
import { registerPendingOrdersPage } from "./pending_orders.js";
import { registerMapPage } from "./map.js";
import { registerSettingsPage } from "./settings.js";
import { registerAccountDeletionsPage } from "./account_deletions.js";
import { registerUsersPage } from "./users.js";
import { registerDriversPage } from "./drivers.js";
import { registerMerchantsPage } from "./merchants.js";
import { registerPromosPage } from "./promos.js";
import { registerWithdrawalsPage } from "./withdrawals.js";
import { registerTopupsPage } from "./topups.js";
import { registerMenusPage } from "./menus.js";
import { registerRevenuePage } from "./revenue.js";
import { registerComplaintsPage } from "./complaints.js";
import { registerReferralsPage } from "./referrals.js";

export function registerInitialPages(reg) {
  registerDashboardPage(reg);
  registerOrdersPage(reg);
  registerPendingOrdersPage(reg);
  registerMapPage(reg);
  registerSettingsPage(reg);
  registerAccountDeletionsPage(reg);
  registerUsersPage(reg);
  registerDriversPage(reg);
  registerMerchantsPage(reg);
  registerPromosPage(reg);
  registerWithdrawalsPage(reg);
  registerTopupsPage(reg);
  registerMenusPage(reg);
  registerRevenuePage(reg);
  registerComplaintsPage(reg);
  registerReferralsPage(reg);
}
