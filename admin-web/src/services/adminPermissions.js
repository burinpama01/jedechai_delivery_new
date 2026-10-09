// GENERATED จาก supabase/functions/_shared/admin-permissions.ts — ห้ามแก้ตรงนี้
// แก้ที่ไฟล์ TS แล้วรัน: node scripts/sync-admin-permissions-web.mjs
// ทีมแอดมิน: แคตตาล็อก action ของ admin-actions + ตัดสินสิทธิ์ (pure — ทดสอบได้ด้วย node)
// แบบ: Plan/Admin_Staff_Permissions_Design_v1.html · แผน: Plan/Admin_Staff_P1_Implementation_v1.html
//
// kind:
//   read      — อ่านอย่างเดียว ต้องมีระดับ "ดู" ขึ้นไป
//   write     — ต้องมีระดับ "แก้ไข" ขึ้นไป
//   sensitive — ระดับ "อนุมัติ" ทำได้เลย / "แก้ไข" ต้องส่งขออนุมัติ
//   super     — superadmin เท่านั้น (เปิดรายคนได้ด้วย override ราย action)
//   team      — จัดการทีม/สิทธิ์ superadmin เท่านั้น เสมอ (override ไม่มีผล)
//   approval  — คำสั่งของระบบคำขออนุมัติเอง (ตรวจสิทธิ์ใน handler)
// action ที่ไม่อยู่ในแคตตาล็อก: staff ถูกปฏิเสธเสมอ (fail closed)

                                                                                        
                                                             
                                                     

                               
                  
                   
                
 

                              
                                            
                  
                                 
                                   
 

export const ADMIN_PAGES                         = {
  dashboard: "แดชบอร์ด",
  orders: "ออเดอร์ทั้งหมด",
  pending_orders: "ออเดอร์รอจัดการ",
  map: "แผนที่ Realtime",
  drivers: "คนขับ",
  merchants: "ร้านค้า",
  users: "ผู้ใช้",
  withdrawals: "ถอนเงิน",
  topups: "เติมเงิน",
  customer_wallets: "กระเป๋าลูกค้า",
  revenue: "รายได้",
  menus: "เมนูร้านค้า",
  ai_menu_import: "AI นำเข้าเมนู",
  shop_stores: "ร้านฝากซื้อ",
  shop_orders: "ออเดอร์ฝากซื้อ",
  laundry: "ซักรีด",
  complaints: "ร้องเรียน",
  reviews: "รีวิว",
  promos: "โค้ดส่วนลด",
  broadcast: "ส่งประกาศ",
  referrals: "ชวนเพื่อน",
  notification_deliveries: "Delivery Log แจ้งเตือน",
  account_deletions: "คำขอลบบัญชี",
  settings: "ตั้งค่าระบบ",
  approvals: "คำขออนุมัติ",
};

const ORDER_PAGES = ["orders", "pending_orders", "map"];
const PEOPLE_PAGES = [
  "users", "drivers", "merchants", "withdrawals", "topups", "customer_wallets",
  "orders", "pending_orders", "account_deletions", "complaints",
];

const e = (pages          , kind            , label        )               => ({ pages, kind, label });

export const ACTION_CATALOG                               = {
  // คนขับ
  approve_driver: e(["drivers"], "sensitive", "อนุมัติคนขับ"),
  reject_driver: e(["drivers"], "write", "ปฏิเสธคนขับ"),
  edit_driver: e(["drivers"], "write", "แก้ไขข้อมูลคนขับ"),
  add_driver: e(["drivers"], "sensitive", "เพิ่มคนขับ (อนุมัติทันที)"),
  set_online_status: e(["drivers", "map"], "write", "เปลี่ยนสถานะออนไลน์"),
  // ร้านค้า
  approve_merchant: e(["merchants"], "sensitive", "อนุมัติร้านค้า"),
  reject_merchant: e(["merchants"], "write", "ปฏิเสธร้านค้า"),
  edit_merchant: e(["merchants"], "sensitive", "แก้ไขข้อมูล/อัตราร้านค้า"),
  add_merchant: e(["merchants"], "sensitive", "เพิ่มร้านค้า (อนุมัติทันที)"),
  toggle_shop_status: e(["merchants"], "write", "เปิด/ปิดร้าน"),
  upsert_gp_plan: e(["merchants"], "sensitive", "บันทึกแพ็กเกจ GP"),
  delete_gp_plan: e(["merchants"], "sensitive", "ลบแพ็กเกจ GP"),
  // ผู้ใช้
  suspend_user: e(["users", "drivers", "merchants"], "sensitive", "ระงับผู้ใช้"),
  unsuspend_user: e(["users", "drivers", "merchants"], "write", "ยกเลิกระงับผู้ใช้"),
  delete_user: e(["users"], "sensitive", "ลบผู้ใช้"),
  edit_user: e(["users"], "write", "แก้ไขข้อมูลผู้ใช้"),
  fetch_user_emails: e(PEOPLE_PAGES, "read", "ดูอีเมลผู้ใช้"),
  // การเงิน
  approve_withdrawal: e(["withdrawals"], "sensitive", "อนุมัติถอนเงิน"),
  approve_withdrawal_with_slip: e(["withdrawals"], "sensitive", "อนุมัติถอนเงิน (แนบสลิป)"),
  reject_withdrawal: e(["withdrawals"], "write", "ปฏิเสธถอนเงิน"),
  approve_topup: e(["topups"], "sensitive", "อนุมัติเติมเงิน"),
  reject_topup: e(["topups"], "write", "ปฏิเสธเติมเงิน"),
  get_topup_slip_url: e(["topups"], "read", "ดูสลิปเติมเงิน"),
  manual_topup: e(["topups", "customer_wallets"], "sensitive", "เติมเงินให้ผู้ใช้"),
  wallet_adjust: e(["customer_wallets"], "sensitive", "ปรับยอดกระเป๋าเงิน"),
  release_referral_reward: e(["referrals"], "sensitive", "ปล่อยรางวัลชวนเพื่อน"),
  // ออเดอร์
  reassign_order: e(ORDER_PAGES, "write", "เปลี่ยนคนขับ"),
  assign_order: e(ORDER_PAGES, "write", "มอบหมายคนขับ"),
  cancel_order: e(ORDER_PAGES, "write", "ยกเลิกออเดอร์"),
  force_cancel_order: e(ORDER_PAGES, "sensitive", "บังคับยกเลิกออเดอร์"),
  rebroadcast_order: e(ORDER_PAGES, "write", "ส่งงานหาคนขับใหม่"),
  edit_order_items: e(ORDER_PAGES, "write", "แก้รายการในออเดอร์"),
  accept_order_as_merchant: e(ORDER_PAGES, "write", "รับออเดอร์แทนร้าน"),
  mark_food_ready_as_merchant: e(ORDER_PAGES, "write", "แจ้งอาหารพร้อมแทนร้าน"),
  // ลบบัญชี
  approve_account_deletion: e(["account_deletions"], "sensitive", "อนุมัติลบบัญชี"),
  approve_deletion: e(["account_deletions"], "sensitive", "อนุมัติลบบัญชี"),
  reject_account_deletion: e(["account_deletions"], "write", "ปฏิเสธลบบัญชี"),
  reject_deletion: e(["account_deletions"], "write", "ปฏิเสธลบบัญชี"),
  // โปรโมชัน
  create_coupon: e(["promos"], "write", "สร้างคูปอง"),
  toggle_coupon: e(["promos"], "write", "เปิด/ปิดคูปอง"),
  delete_coupon: e(["promos"], "write", "ลบคูปอง"),
  update_coupon: e(["promos"], "write", "แก้ไขคูปอง"),
  // เมนู
  create_menu_item: e(["menus"], "write", "เพิ่มเมนู"),
  update_menu_item: e(["menus"], "write", "แก้ไขเมนู"),
  delete_menu_item: e(["menus"], "write", "ลบเมนู"),
  create_menu_option: e(["menus"], "write", "เพิ่มตัวเลือกเมนู"),
  update_menu_option: e(["menus"], "write", "แก้ไขตัวเลือกเมนู"),
  delete_menu_option: e(["menus"], "write", "ลบตัวเลือกเมนู"),
  create_menu_option_group: e(["menus"], "write", "เพิ่มกลุ่มตัวเลือก"),
  delete_option_group: e(["menus"], "write", "ลบกลุ่มตัวเลือก"),
  create_option_group_and_link: e(["menus"], "write", "สร้างและผูกกลุ่มตัวเลือก"),
  toggle_link_group: e(["menus"], "write", "ผูก/เลิกผูกกลุ่มตัวเลือก"),
  unlink_option_group: e(["menus"], "write", "เลิกผูกกลุ่มตัวเลือก"),
  // ซักรีด
  list_laundry_packages: e(["laundry"], "read", "ดูแพ็กเกจซักรีด"),
  manage_laundry_package: e(["laundry"], "write", "จัดการแพ็กเกจซักรีด"),
  delete_laundry_package: e(["laundry"], "write", "ลบแพ็กเกจซักรีด"),
  admin_laundry_send_quote: e(["laundry"], "write", "ส่งใบเสนอราคาซักรีด"),
  admin_laundry_update_status: e(["laundry"], "write", "เปลี่ยนสถานะซักรีด"),
  admin_laundry_create_return_booking: e(["laundry"], "write", "สร้างงานส่งคืนซักรีด"),
  admin_laundry_cancel: e(["laundry"], "write", "ยกเลิกงานซักรีด"),
  // ร้องเรียน / รีวิว / ประกาศ
  update_ticket_status: e(["complaints"], "write", "เปลี่ยนสถานะเรื่องร้องเรียน"),
  resolve_ticket: e(["complaints"], "write", "ปิดเรื่องร้องเรียน"),
  admin_delete_review: e(["reviews"], "write", "ลบรีวิว"),
  admin_broadcast_notification: e(["broadcast"], "sensitive", "ส่งประกาศ"),
  // ตั้งค่าระบบ
  get_beam_settings: e(["settings"], "super", "ดูตั้งค่า Beam"),
  save_beam_settings: e(["settings"], "super", "บันทึกตั้งค่า Beam"),
  test_beam_connection: e(["settings"], "super", "ทดสอบ Beam"),
  set_topup_mode: e(["settings"], "super", "เปลี่ยนโหมดเติมเงิน"),
  upsert_system_config: e(["settings"], "super", "บันทึกตั้งค่าระบบ"),
  upsert_system_config_kv: e(["settings"], "super", "บันทึกตั้งค่าระบบ"),
  create_banner: e(["settings"], "super", "สร้างแบนเนอร์"),
  toggle_banner: e(["settings"], "super", "เปิด/ปิดแบนเนอร์"),
  delete_banner: e(["settings"], "super", "ลบแบนเนอร์"),
  // ทีมแอดมิน (superadmin เสมอ)
  team_add_existing: e([], "team", "เพิ่มบัญชีเดิมเข้าทีม"),
  team_create_account: e([], "team", "สร้างบัญชีทีมใหม่"),
  team_update: e([], "team", "แก้ไขสมาชิกทีม/สิทธิ์"),
  team_remove: e([], "team", "นำออกจากทีม"),
  team_reset_link: e([], "team", "สร้างลิงก์ตั้งรหัสผ่าน"),
  superadmin_grant: e([], "team", "แต่งตั้ง superadmin"),
  superadmin_revoke: e([], "team", "ถอด superadmin"),
  template_upsert: e([], "team", "บันทึกบทบาท"),
  template_delete: e([], "team", "ลบบทบาท"),
  // คำขออนุมัติ
  approval_decide: e(["approvals"], "approval", "พิจารณาคำขอ"),
  approval_cancel: e(["approvals"], "approval", "ยกเลิกคำขอ"),
};

const LEVEL_RANK                         = { none: 0, view: 1, edit: 2, approve: 3 };

export function normalizeLevel(value         )            {
  return value === "view" || value === "edit" || value === "approve" ? value : "none";
}

/** ระดับสูงสุดของผู้ใช้ในบรรดาหน้าที่ action นี้ใช้ */
export function bestLevel(access             , pages          )            {
  let best            = "none";
  for (const page of pages) {
    const level = normalizeLevel(access.pages?.[page]);
    if (LEVEL_RANK[level] > LEVEL_RANK[best]) best = level;
  }
  return best;
}

export function decideAccess(access                                , action        )           {
  if (!access || access.active !== true) return "deny";
  if (access.tier === "superadmin") return "allow";
  if (access.tier !== "lead" && access.tier !== "assistant") return "deny";

  const entry = ACTION_CATALOG[action];
  if (!entry) return "deny";
  if (entry.kind === "team") return "deny";
  if (entry.kind === "approval") return "allow"; // handler ตรวจสิทธิ์รายคำขอเอง

  const override = access.actions?.[action];
  if (override === "deny") return "deny";
  if (override === "allow") return "allow";
  if (override === "require_approval") return entry.kind === "read" ? "deny" : "approval";

  const level = bestLevel(access, entry.pages);
  switch (entry.kind) {
    case "read":
      return LEVEL_RANK[level] >= LEVEL_RANK.view ? "allow" : "deny";
    case "write":
      return LEVEL_RANK[level] >= LEVEL_RANK.edit ? "allow" : "deny";
    case "sensitive":
      if (level === "approve") return "allow";
      if (level === "edit") return "approval";
      return "deny";
    default:
      return "deny"; // super ต้องมี override
  }
}

/** ผู้ใช้นี้พิจารณาคำขอที่มีหน้า pages ได้ไหม (ห้ามพิจารณาคำขอของตัวเอง) */
export function canDecideApproval(
  access                                ,
  pages          ,
  actorId        ,
  requesterId        ,
)          {
  if (!access || access.active !== true) return false;
  if (actorId === requesterId) return false;
  if (access.tier === "superadmin") return true;
  if (access.tier !== "lead") return false;
  return pages.some((page) => normalizeLevel(access.pages?.[page]) === "approve");
}

/** ตรวจ/ทำความสะอาด page_levels ของบทบาท — เก็บเฉพาะหน้าที่รู้จักและระดับที่ถูกต้อง */
export function sanitizePageLevels(raw         )                            {
  const out                            = {};
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return out;
  for (const [page, level] of Object.entries(raw                           )) {
    if (!(page in ADMIN_PAGES) || page === "settings") continue;
    const normalized = normalizeLevel(level);
    if (normalized !== "none") out[page] = normalized;
  }
  return out;
}

/** ตรวจ action override — เฉพาะ action ในแคตตาล็อกที่ไม่ใช่ team/approval */
export function sanitizeActionOverrides(raw         )                                                        {
  const out                                                        = {};
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return out;
  for (const [action, effect] of Object.entries(raw                           )) {
    const entry = ACTION_CATALOG[action];
    if (!entry || entry.kind === "team" || entry.kind === "approval") continue;
    if (effect === "allow" || effect === "deny" || effect === "require_approval") out[action] = effect;
  }
  return out;
}

/** override รายหน้าของสมาชิก — ต่างจาก sanitizePageLevels ตรงที่เก็บ "none" ไว้ (ใช้ปิดหน้าที่บทบาทให้มา) */
export function sanitizePageOverrides(raw         )                            {
  const out                            = {};
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return out;
  for (const [page, level] of Object.entries(raw                           )) {
    if (!(page in ADMIN_PAGES) || page === "settings") continue;
    if (level === "none" || level === "view" || level === "edit" || level === "approve") out[page] = level;
  }
  return out;
}
