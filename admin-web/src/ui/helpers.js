export function wireLegacyHelpers({ fmt, fmtDate, exportRowsToCsv, exportRowsToExcel, showToast }) {
  globalThis.__adminWebBridge = globalThis.__adminWebBridge || {};
  if (fmt) globalThis.__adminWebBridge.fmt = fmt;
  if (fmtDate) globalThis.__adminWebBridge.fmtDate = fmtDate;
  if (exportRowsToCsv) globalThis.__adminWebBridge.exportRowsToCsv = exportRowsToCsv;
  if (exportRowsToExcel) globalThis.__adminWebBridge.exportRowsToExcel = exportRowsToExcel;
  if (showToast) globalThis.__adminWebBridge.showToast = showToast;
}
