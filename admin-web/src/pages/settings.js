import { renderSettingsPage } from "./settingsPage.js";

export function registerSettingsPage(reg) {
  if (typeof reg !== "function") return;
  reg("settings", async (el, ctx) => {
    return await renderSettingsPage(el, ctx);
  });
}
