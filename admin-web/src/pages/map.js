import { renderMapPage, disposeMapPage } from "./mapPage.js";

export function registerMapPage(reg) {
  if (typeof reg !== "function") return;
  reg(
    "map",
    async (el, ctx) => {
      return await renderMapPage(el, ctx);
    },
    {
      dispose: async (ctx) => {
        return await disposeMapPage(ctx);
      },
    },
  );
}
