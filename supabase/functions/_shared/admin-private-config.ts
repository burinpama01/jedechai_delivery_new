// ค่าลับของแอดมิน (อีเมล/LINE/Telegram/บัญชีรับเงิน Slip2Go) ย้ายจาก system_config ไป
// system_config_private (migration 20261008120000) เพราะ system_config อ่านได้สาธารณะ
//
// withAdminPrivateConfig(): เติมค่าจาก system_config_private ทับแถว system_config ที่อ่านมา
// — ใช้ค่า private ถ้ามี, ไม่มีตาราง/อ่านไม่ได้ → คงค่าเดิมจาก system_config (รองรับช่วงก่อน apply migration)
// ต้องเรียกด้วย client service_role เท่านั้น

export const ADMIN_PRIVATE_CONFIG_COLUMNS = [
  "admin_notification_email",
  "admin_notification_email_cc",
  "admin_line_recipient_id",
  "admin_telegram_chat_id",
  "slip2go_receiver_account",
] as const;

type Row = Record<string, unknown>;

// คืน any ให้เหมือนผล .maybeSingle() เดิมของ client ที่ไม่มี generic (โค้ดเรียกใช้ไม่ต้องแก้ type)
// deno-lint-ignore no-explicit-any
export async function withAdminPrivateConfig(supabaseAdmin: any, config: any): Promise<any> {
  try {
    const { data, error } = await supabaseAdmin
      .from("system_config_private")
      .select(ADMIN_PRIVATE_CONFIG_COLUMNS.join(", "))
      .eq("id", 1)
      .maybeSingle();
    if (error) throw error;
    if (!data) return config;
    return mergeAdminPrivateConfig(config, data);
  } catch (error) {
    console.warn("system_config_private lookup failed, using system_config:", (error as Error)?.message || error);
    return config;
  }
}

export function mergeAdminPrivateConfig(config: Row | null | undefined, privateRow: Row | null | undefined): Row {
  const merged: Row = { ...(config || {}) };
  for (const column of ADMIN_PRIVATE_CONFIG_COLUMNS) {
    const value = privateRow?.[column];
    if (typeof value === "string" && value.trim()) merged[column] = value;
  }
  return merged;
}
