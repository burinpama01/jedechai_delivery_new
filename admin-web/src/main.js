import { getConfig, validateConfig } from "./config.js";
import { createSupabaseClients } from "./services/supabaseClient.js";
import { setInMemorySessionFromSupabaseSession, safeSignOut, checkExistingAdminSession } from "./services/authService.js";
import { callAdminAction } from "./services/adminActionsApi.js";
import { fmt, fmtDate } from "./utils/format.js";
import { exportRowsToCsv, exportRowsToExcel } from "./utils/export.js";
import { showToast } from "./ui/toast.js";
import { wireLegacyHelpers } from "./ui/helpers.js";
import { wireRouterBridge } from "./router/bridge.js";
import { registerInitialPages } from "./pages/index.js";
import { wireWithdrawalsBridge } from "./pages/withdrawalsPage.js";
import { wirePromosBridge } from "./pages/promosPage.js";
import { wireDashboardBridge } from "./pages/dashboardPage.js";
import { wireOrdersBridge } from "./pages/ordersPage.js";
import { wireOrdersActionsBridge } from "./pages/ordersActions.js";
import { wirePendingOrdersBridge } from "./pages/pendingOrdersPage.js";
import { wireMapBridge } from "./pages/mapPage.js";
import { wireMapActionsBridge } from "./pages/mapActions.js";
import { wireSettingsBridge } from "./pages/settingsPage.js";
import { wireAccountDeletionsBridge } from "./pages/accountDeletionsPage.js";
import { wireUsersBridge } from "./pages/usersPage.js";
import { wireDriversBridge } from "./pages/driversPage.js";
import { wireMerchantsBridge } from "./pages/merchantsPage.js";
import { wireTopupsBridge } from "./pages/topupsPage.js";
import { wireMenusBridge } from "./pages/menusPage.js";
import { wireRevenueBridge } from "./pages/revenuePage.js";
import { wireComplaintsBridge } from "./pages/complaintsPage.js";
import { wireBannersBridge } from "./pages/bannersBridge.js";
import { wireAssetsBridge } from "./pages/assetsBridge.js";
import { wireSettingsActionsBridge } from "./pages/settingsActionsBridge.js";
import { wireReferralsBridge } from "./pages/referralsPage.js";

function _projectHost(url) {
  try {
    return new URL(url).host;
  } catch (_) {
    return "unknown";
  }
}

function initSupabaseLegacyBridge() {
  const config = getConfig();
  const validation = validateConfig(config);
  if (!validation.ok) {
    return { ok: false, error: validation.error };
  }

  const storageKey = `jedechai_admin_web_auth_${_projectHost(config.SUPABASE_URL)}`;

  try {
    const { supabase, supabaseAuth } = createSupabaseClients({
      SUPABASE_URL: config.SUPABASE_URL,
      SUPABASE_ANON_KEY: config.SUPABASE_ANON_KEY,
      storageKey,
    });
    return { ok: true, supabase, supabaseAuth };
  } catch (e) {
    return { ok: false, error: e?.message || "init_failed" };
  }
}

globalThis.__adminWebBridge = globalThis.__adminWebBridge || {};
globalThis.__adminWebBridge.initSupabase = initSupabaseLegacyBridge;
globalThis.__adminWebBridge.setInMemorySessionFromSupabaseSession = setInMemorySessionFromSupabaseSession;
globalThis.__adminWebBridge.safeSignOut = safeSignOut;
globalThis.__adminWebBridge.checkExistingAdminSession = checkExistingAdminSession;
globalThis.__adminWebBridge.callAdminAction = callAdminAction;

wireLegacyHelpers({ fmt, fmtDate, exportRowsToCsv, exportRowsToExcel, showToast });
wireRouterBridge();
wireWithdrawalsBridge();
wirePromosBridge();
wireDashboardBridge();
wireOrdersBridge();
wireOrdersActionsBridge();
wirePendingOrdersBridge();
wireMapBridge();
wireMapActionsBridge();
wireSettingsBridge();
wireAccountDeletionsBridge();
wireUsersBridge();
wireDriversBridge();
wireMerchantsBridge();
wireTopupsBridge();
wireMenusBridge();
wireRevenueBridge();
wireComplaintsBridge();
wireBannersBridge();
wireAssetsBridge();
wireSettingsActionsBridge();
wireReferralsBridge();

try {
  const reg = globalThis.__adminWebBridge?.registerPage;
  registerInitialPages(reg);
} catch (_) {
  // ignore and keep legacy behavior
}

export function bootstrap() {
  return true;
}
