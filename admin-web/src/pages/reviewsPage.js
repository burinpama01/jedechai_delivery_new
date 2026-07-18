function _deps(ctx) {
  return {
    supabase: ctx?.supabase || globalThis.supabase,
    escapeHtml:
      ctx?.escapeHtml ||
      globalThis.escapeHtml ||
      ((value) => String(value ?? "")),
    fmtDate:
      ctx?.fmtDate ||
      globalThis.fmtDate ||
      globalThis.__adminWebBridge?.fmtDate ||
      ((value) => (value ? new Date(value).toLocaleString("th-TH") : "-")),
    showToast:
      ctx?.showToast ||
      globalThis.showToast ||
      globalThis.__adminWebBridge?.showToast ||
      (() => {}),
    callAdminAction:
      ctx?.callAdminAction ||
      globalThis.callAdminAction ||
      null,
  };
}

function starsHtml(rating) {
  const rounded = Math.round(Number(rating || 0));
  const full = "★".repeat(Math.max(0, Math.min(5, rounded)));
  const empty = "☆".repeat(Math.max(0, 5 - rounded));
  return `<span class="text-amber-500">${full}</span><span class="text-gray-300">${empty}</span>`;
}

async function loadReviews(supabase) {
  const { data, error } = await supabase
    .from("reviews")
    .select("id, booking_id, customer_id, driver_id, merchant_id, rating, comment, created_at")
    .order("created_at", { ascending: false })
    .limit(200);
  if (error) throw error;

  const profileIds = [...new Set((data || [])
    .flatMap((row) => [row.customer_id, row.driver_id, row.merchant_id])
    .filter(Boolean))];
  let profiles = {};
  if (profileIds.length) {
    const { data: profileRows, error: profileError } = await supabase
      .from("profiles")
      .select("id, full_name, phone_number, role")
      .in("id", profileIds);
    if (profileError) throw profileError;
    profiles = Object.fromEntries((profileRows || []).map((p) => [p.id, p]));
  }
  return { reviews: data || [], profiles };
}

function profileName(profiles, id) {
  const profile = profiles[id];
  if (!profile) return id ? `#${String(id).slice(0, 8)}` : "-";
  return profile.full_name || profile.phone_number || `#${String(id).slice(0, 8)}`;
}

function matchesFilters(review, profiles, targetFilter, ratingFilter, searchText) {
  if (targetFilter === "driver" && !review.driver_id) return false;
  if (targetFilter === "merchant" && !review.merchant_id) return false;
  if (ratingFilter && Math.round(Number(review.rating || 0)) !== Number(ratingFilter)) return false;

  const query = String(searchText || "").trim().toLowerCase();
  if (!query) return true;
  const haystack = [
    review.comment,
    review.booking_id,
    profileName(profiles, review.customer_id),
    profileName(profiles, review.driver_id),
    profileName(profiles, review.merchant_id),
  ].join(" ").toLowerCase();
  return haystack.includes(query);
}

export async function deleteReview(reviewId, ctx) {
  const { callAdminAction, showToast } = _deps(ctx);
  if (typeof callAdminAction !== "function") {
    showToast("ไม่พบ admin action สำหรับลบรีวิว", "error");
    return;
  }
  if (typeof globalThis.confirm === "function" &&
    !globalThis.confirm("ลบรีวิวนี้ถาวร? คะแนนเฉลี่ยของผู้ถูกรีวิวจะถูกคำนวณใหม่")) return;

  try {
    await callAdminAction({ action: "admin_delete_review", review_id: reviewId });
    showToast("ลบรีวิวแล้ว", "success");
    if (typeof ctx?.render === "function") await ctx.render();
  } catch (err) {
    showToast(`ลบรีวิวไม่สำเร็จ: ${err.message || err}`, "error");
  }
}

export async function renderReviewsPage(el, ctx) {
  const { supabase, escapeHtml, fmtDate, showToast } = _deps(ctx);
  if (!supabase) {
    el.innerHTML = '<div class="p-6 text-red-600">Supabase client unavailable</div>';
    return;
  }

  el.innerHTML = `
    <div class="bg-white rounded-3xl border border-gray-100 shadow-sm p-5 mb-6">
      <div class="flex flex-col md:flex-row md:items-center md:justify-between gap-3">
        <div>
          <h2 class="text-xl font-bold text-gray-900">รีวิวจากลูกค้า</h2>
          <p class="text-sm text-gray-500">ตรวจสอบรีวิวคนขับ/ร้านค้า และลบรีวิวที่ไม่เหมาะสม (200 รายการล่าสุด)</p>
        </div>
        <div class="flex flex-wrap items-center gap-2">
          <select id="reviewTargetFilter" class="rounded-xl border border-gray-200 bg-white px-3 py-2 text-sm">
            <option value="">ทุกประเภท</option>
            <option value="driver">รีวิวคนขับ</option>
            <option value="merchant">รีวิวร้านค้า</option>
          </select>
          <select id="reviewRatingFilter" class="rounded-xl border border-gray-200 bg-white px-3 py-2 text-sm">
            <option value="">ทุกดาว</option>
            <option value="1">1 ดาว</option>
            <option value="2">2 ดาว</option>
            <option value="3">3 ดาว</option>
            <option value="4">4 ดาว</option>
            <option value="5">5 ดาว</option>
          </select>
          <input id="reviewSearchInput" placeholder="ค้นหา ข้อความ/ชื่อ/booking..."
            class="rounded-xl border border-gray-200 px-3 py-2 text-sm w-[200px]">
          <button id="reviewRefreshBtn" class="px-4 py-2 bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-xl text-sm font-semibold">รีเฟรช</button>
        </div>
      </div>
    </div>
    <div id="reviewsContent" class="bg-white rounded-3xl border border-gray-100 shadow-sm p-5">
      <div class="text-center text-gray-400 py-12">กำลังโหลด...</div>
    </div>
  `;

  let cache = null;

  const draw = () => {
    const content = el.querySelector("#reviewsContent");
    if (!content || !cache) return;
    const { reviews, profiles } = cache;
    const targetFilter = el.querySelector("#reviewTargetFilter")?.value || "";
    const ratingFilter = el.querySelector("#reviewRatingFilter")?.value || "";
    const searchText = el.querySelector("#reviewSearchInput")?.value || "";
    const visible = reviews.filter((review) =>
      matchesFilters(review, profiles, targetFilter, ratingFilter, searchText));

    const avgRating = reviews.length
      ? (reviews.reduce((sum, r) => sum + Number(r.rating || 0), 0) / reviews.length)
      : 0;
    const lowCount = reviews.filter((r) => Number(r.rating || 0) <= 2).length;

    content.innerHTML = `
      <div class="grid grid-cols-2 lg:grid-cols-4 gap-3 mb-5">
        <div class="rounded-2xl bg-gray-50 p-4">
          <p class="text-xs text-gray-500">รีวิวทั้งหมด (ชุดล่าสุด)</p>
          <p class="text-2xl font-bold text-gray-900">${reviews.length}</p>
        </div>
        <div class="rounded-2xl bg-amber-50 p-4">
          <p class="text-xs text-amber-700">คะแนนเฉลี่ย</p>
          <p class="text-2xl font-bold text-amber-700">${avgRating.toFixed(2)}</p>
        </div>
        <div class="rounded-2xl bg-rose-50 p-4">
          <p class="text-xs text-rose-700">รีวิว ≤ 2 ดาว</p>
          <p class="text-2xl font-bold text-rose-700">${lowCount}</p>
        </div>
        <div class="rounded-2xl bg-indigo-50 p-4">
          <p class="text-xs text-indigo-700">แสดงตามตัวกรอง</p>
          <p class="text-2xl font-bold text-indigo-700">${visible.length}</p>
        </div>
      </div>
      <div class="overflow-x-auto">
        <table class="min-w-full text-sm">
          <thead>
            <tr class="text-left text-xs uppercase tracking-wide text-gray-400 border-b border-gray-100">
              <th class="py-3 px-3">วันที่</th>
              <th class="py-3 px-3">ลูกค้า</th>
              <th class="py-3 px-3">ผู้ถูกรีวิว</th>
              <th class="py-3 px-3">คะแนน</th>
              <th class="py-3 px-3">คอมเมนต์</th>
              <th class="py-3 px-3">Booking</th>
              <th class="py-3 px-3 text-right">จัดการ</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100">
            ${visible.map((review) => {
              const target = review.driver_id
                ? { label: "คนขับ", name: profileName(profiles, review.driver_id), cls: "bg-blue-50 text-blue-700" }
                : { label: "ร้าน", name: profileName(profiles, review.merchant_id), cls: "bg-orange-50 text-orange-700" };
              return `
                <tr class="align-top">
                  <td class="py-3 px-3 text-gray-500 text-xs whitespace-nowrap">${escapeHtml(fmtDate(review.created_at))}</td>
                  <td class="py-3 px-3">
                    <div class="font-semibold text-gray-900">${escapeHtml(profileName(profiles, review.customer_id))}</div>
                  </td>
                  <td class="py-3 px-3">
                    <span class="inline-flex px-2 py-0.5 rounded-full text-[10px] font-semibold ${target.cls} mr-1">${target.label}</span>
                    <span class="text-gray-800">${escapeHtml(target.name)}</span>
                  </td>
                  <td class="py-3 px-3 whitespace-nowrap">${starsHtml(review.rating)} <span class="text-xs text-gray-400">(${Number(review.rating || 0).toFixed(1)})</span></td>
                  <td class="py-3 px-3 text-gray-600 max-w-[280px]"><div class="whitespace-pre-wrap break-words">${escapeHtml(review.comment || "-")}</div></td>
                  <td class="py-3 px-3 font-mono text-xs text-gray-400">#${escapeHtml(String(review.booking_id || "").slice(0, 8))}</td>
                  <td class="py-3 px-3 text-right">
                    <button class="reviewDeleteBtn px-3 py-1.5 rounded-lg bg-rose-50 text-rose-700 text-xs font-semibold hover:bg-rose-100" data-review-id="${escapeHtml(review.id)}">ลบรีวิว</button>
                  </td>
                </tr>
              `;
            }).join("") || `
              <tr>
                <td colspan="7" class="py-10 text-center text-gray-400">${reviews.length ? "ไม่พบรีวิวตามเงื่อนไขที่กรอง" : "ยังไม่มีรีวิว"}</td>
              </tr>
            `}
          </tbody>
        </table>
      </div>
    `;

    for (const button of content.querySelectorAll(".reviewDeleteBtn")) {
      button.addEventListener("click", () => deleteReview(button.dataset.reviewId, { ...ctx, render }));
    }
  };

  const render = async () => {
    const content = el.querySelector("#reviewsContent");
    try {
      cache = await loadReviews(supabase);
      draw();
    } catch (err) {
      if (content) {
        content.innerHTML = `<div class="p-4 rounded-2xl bg-red-50 text-red-700">โหลดรีวิวไม่สำเร็จ: ${escapeHtml(err.message || err)}</div>`;
      }
      showToast(`โหลดรีวิวไม่สำเร็จ: ${err.message || err}`, "error");
    }
  };

  el.querySelector("#reviewRefreshBtn")?.addEventListener("click", render);
  el.querySelector("#reviewTargetFilter")?.addEventListener("change", draw);
  el.querySelector("#reviewRatingFilter")?.addEventListener("change", draw);
  el.querySelector("#reviewSearchInput")?.addEventListener("input", () => {
    clearTimeout(el._reviewSearchTimer);
    el._reviewSearchTimer = setTimeout(draw, 250);
  });
  await render();
}

globalThis.__adminWebBridge = globalThis.__adminWebBridge || {};
globalThis.__adminWebBridge.renderReviewsPage = renderReviewsPage;
globalThis.__adminWebBridge.deleteReview = deleteReview;
