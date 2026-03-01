let _ctx = null;

export async function renderSettingsPage(el, ctx) {
  _ctx = ctx || null;

  const legacy = globalThis.renderSettings;
  if (typeof legacy === 'function') {
    return await legacy(el);
  }

  throw new Error('legacy_renderSettings_not_found');
}

export function wireSettingsBridge() {
  globalThis.__adminWebBridge = globalThis.__adminWebBridge || {};
  globalThis.__adminWebBridge.renderSettingsPage = renderSettingsPage;
}
