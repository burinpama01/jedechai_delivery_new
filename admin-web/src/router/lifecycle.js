export function getLeaveCleanupKeys(nextPage) {
  const keys = [];

  if (nextPage !== "map") {
    keys.push("map");
    keys.push("auto_dispatch");
  }

  if (nextPage !== "pending_orders") {
    keys.push("pending_orders");
  }

  return keys;
}
