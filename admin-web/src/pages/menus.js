import { renderMenusPage } from "./menusPage.js";

export function registerMenusPage(reg) {
  if (typeof reg !== "function") return;
  reg("menus", async (el, ctx) => {
    return await renderMenusPage(el, ctx);
  });
}
