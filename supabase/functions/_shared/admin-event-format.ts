// จัดรูปข้อความแจ้งแอดมิน (Telegram/LINE/อีเมล) — pure, test ได้ (admin-event-format.test.ts)

export const DEFAULT_ADMIN_WEB_URL = "https://jdc-delivery.vercel.app/admin";

/** event ที่ส่งอีเมลด้วย (event อื่นเช่นงานค้าง/เติมเงิน ส่งแค่ Telegram/LINE กันอีเมลท่วม) */
export const EMAIL_EVENT_TYPES = new Set([
  "admin.applicant_pending",
  "admin.daily_signup_summary",
]);

export interface AdminEvent {
  title: string;
  body: string;
  event_type: string;
  data: Record<string, unknown> | null;
}

/** ลิงก์เปิดหน้าใน admin-web จาก data.admin_page (รับเฉพาะชื่อหน้าแบบ a-z/_) */
export function adminPageLink(event: AdminEvent, baseUrl: string = DEFAULT_ADMIN_WEB_URL): string | null {
  const page = typeof event.data?.admin_page === "string" ? event.data.admin_page : "";
  if (!/^[a-z_]{2,40}$/.test(page)) return null;
  const base = (baseUrl || DEFAULT_ADMIN_WEB_URL).replace(/[?#].*$/, "").replace(/\/+$/, "");
  return `${base}?page=${page}`;
}

export function formatChatText(event: AdminEvent, link: string | null): string {
  const lines = [`🔔 ${event.title}`, event.body];
  if (link) lines.push(`🔗 เปิดหน้าจัดการ: ${link}`);
  return lines.join("\n");
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

export function formatEmail(event: AdminEvent, link: string | null): { subject: string; html: string } {
  const bodyHtml = escapeHtml(event.body).replace(/\n/g, "<br>");
  const button = link
    ? `<p style="margin:20px 0"><a href="${escapeHtml(link)}" style="background:#4f46e5;color:#fff;padding:10px 18px;border-radius:10px;text-decoration:none;font-weight:600">เปิดหน้าจัดการใน Admin</a></p>`
    : "";
  return {
    subject: `[JDC Admin] ${event.title}`,
    html: `<div style="font-family:Tahoma,sans-serif;font-size:15px;color:#1f2328">
<h2 style="font-size:18px;margin:0 0 8px">${escapeHtml(event.title)}</h2>
<p style="margin:0">${bodyHtml}</p>${button}
<p style="color:#8a8f98;font-size:12px;margin-top:24px">อีเมลอัตโนมัติจากระบบ JDC Delivery</p></div>`,
  };
}

/** แยกอีเมลจากช่องหลัก + CC (คั่นด้วย , ; หรือช่องว่าง) ตัดซ้ำ/รูปแบบผิด */
export function parseEmailList(...values: (string | null | undefined)[]): string[] {
  const out: string[] = [];
  for (const v of values) {
    for (const part of String(v || "").split(/[,;\s]+/)) {
      const e = part.trim().toLowerCase();
      if (/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e) && !out.includes(e)) out.push(e);
    }
  }
  return out;
}
