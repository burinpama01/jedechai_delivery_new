export function fmt(n) {
  return new Intl.NumberFormat("th-TH").format(n || 0);
}

export function fmtDate(d) {
  return d
    ? new Date(d).toLocaleDateString("th-TH", {
        day: "numeric",
        month: "short",
        year: "numeric",
        hour: "2-digit",
        minute: "2-digit",
      })
    : "-";
}
