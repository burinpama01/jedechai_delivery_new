import { getPageTitles, getPageTitle } from "./meta.js";
import { getLeaveCleanupKeys } from "./lifecycle.js";
import { registerPage, renderPage, disposeActivePage, getActivePage, hasPage } from "./router.js";

export function wireRouterBridge() {
  globalThis.__adminWebBridge = globalThis.__adminWebBridge || {};
  globalThis.__adminWebBridge.getPageTitles = getPageTitles;
  globalThis.__adminWebBridge.getPageTitle = getPageTitle;
  globalThis.__adminWebBridge.getLeaveCleanupKeys = getLeaveCleanupKeys;
  globalThis.__adminWebBridge.registerPage = registerPage;
  globalThis.__adminWebBridge.renderRegisteredPage = renderPage;
  globalThis.__adminWebBridge.disposeRegisteredPage = disposeActivePage;
  globalThis.__adminWebBridge.getActiveRegisteredPage = getActivePage;
  globalThis.__adminWebBridge.hasRegisteredPage = hasPage;
}
