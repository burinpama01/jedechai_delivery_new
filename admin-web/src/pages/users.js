import { renderUsersPage } from "./usersPage.js";

export function registerUsersPage(reg) {
  if (typeof reg !== "function") return;
  reg("users", async (el, ctx) => {
    return await renderUsersPage(el, ctx);
  });
}
