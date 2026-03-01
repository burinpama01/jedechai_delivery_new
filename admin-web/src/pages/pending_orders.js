import { renderPendingOrdersPage, disposePendingOrdersPage } from "./pendingOrdersPage.js";

export function registerPendingOrdersPage(reg) {
  if (typeof reg !== "function") return;
  reg(
    "pending_orders",
    async (el, ctx) => {
      return await renderPendingOrdersPage(el, ctx);
    },
    {
      dispose: async (ctx) => {
        return await disposePendingOrdersPage(ctx);
      },
    },
  );
}
