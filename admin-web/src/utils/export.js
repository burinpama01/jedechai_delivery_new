function _csvCell(value) {
  const v = value == null ? "" : String(value);
  return `"${v.replace(/"/g, '""')}"`;
}

export function exportRowsToCsv(filename, headers, rows) {
  const csv = [
    headers.map(_csvCell).join(","),
    ...(rows || []).map((row) => headers.map((h) => _csvCell(row[h])).join(",")),
  ].join("\n");

  const blob = new Blob(["\uFEFF" + csv], { type: "text/csv;charset=utf-8;" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

export function exportRowsToExcel(filename, headers, rows) {
  const headHtml = headers
    .map(
      (h) =>
        `<th style="border:1px solid #d1d5db;padding:8px;background:#f9fafb">${h}</th>`,
    )
    .join("");

  const bodyHtml = (rows || [])
    .map((row) => {
      const cols = headers
        .map(
          (h) =>
            `<td style="border:1px solid #e5e7eb;padding:8px">${row[h] ?? ""}</td>`,
        )
        .join("");
      return `<tr>${cols}</tr>`;
    })
    .join("");

  const html = `
    <html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:x="urn:schemas-microsoft-com:office:excel" xmlns="http://www.w3.org/TR/REC-html40">
      <head><meta charset="UTF-8"></head>
      <body>
        <table>
          <thead><tr>${headHtml}</tr></thead>
          <tbody>${bodyHtml}</tbody>
        </table>
      </body>
    </html>`;

  const blob = new Blob([html], { type: "application/vnd.ms-excel;charset=utf-8;" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}
