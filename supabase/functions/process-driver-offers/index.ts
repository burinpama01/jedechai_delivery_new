import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { "Content-Type": "application/json; charset=utf-8" },
});

// เทียบ secret แบบเวลาคงที่ (ความยาว secret ตายตัว การคืนเร็วเมื่อความยาวต่างจึงไม่รั่วข้อมูล)
function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

serve(async (request) => {
  if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) return json({ error: "server_config_missing" }, 500);
  // ยืนยันตัวด้วย x-cron-secret แบบเดียวกับ notify-admin-events
  // (เทียบ Bearer กับ SUPABASE_SERVICE_ROLE_KEY ใช้กับ cron ไม่ได้ เพราะ runtime ไม่ได้ฉีด
  //  legacy JWT ตัวที่ Dashboard แสดง -> 401 ทุกครั้ง)
  const cronSecret = Deno.env.get("DRIVER_OFFER_CRON_SECRET")?.trim() ?? "";
  const providedSecret = request.headers.get("x-cron-secret")?.trim() ?? "";
  if (cronSecret.length < 32 || !timingSafeEqual(providedSecret, cronSecret)) {
    return json({ error: "unauthorized" }, 401);
  }

  const db = createClient(url, serviceKey);
  const { error: queueError } = await db.rpc("process_driver_offer_queue", { p_limit: 100 });
  if (queueError) return json({ error: "queue_failed", detail: queueError.message }, 500);

  const { data: claims, error: claimError } = await db.rpc("claim_driver_offer_pushes", { p_limit: 100 });
  if (claimError) return json({ error: "push_claim_failed", detail: claimError.message }, 500);

  const startedAt = Date.now();
  const processOffer = async (offer: NonNullable<typeof claims>[number]) => {
    // A driver may have skipped while this worker was processing the batch.
    const { data: current } = await db.from("driver_job_offers")
      .select("status, expires_at, push_sent_at")
      .eq("id", offer.offer_id).maybeSingle();
    if (!current || current.status !== "offered" || current.push_sent_at ||
        Date.parse(current.expires_at) <= Date.now() + 3000) return "expired";

    try {
      const response = await fetch(`${url}/functions/v1/send-fcm-notification`, {
        method: "POST",
        signal: AbortSignal.timeout(6000),
        headers: {
          Authorization: `Bearer ${serviceKey}`,
          apikey: serviceKey,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          user_ids: [offer.driver_id],
          title: "มีงานใหม่รอรับ",
          message: "โปรดรับหรือข้ามงานภายใน 60 วินาที",
          notification_id: offer.notification_id,
          persist_in_app: false,
          data: {
            type: "driver.job.offer",
            booking_id: offer.booking_id,
            offer_id: offer.offer_id,
            expires_at: offer.expires_at,
          },
        }),
      });
      const result = await response.json();
      if (response.ok && result.results?.[0]?.success === true) {
        const { error } = await db.from("driver_job_offers")
          .update({ push_sent_at: new Date().toISOString() })
          .eq("id", offer.offer_id).eq("status", "offered").is("push_sent_at", null);
        if (error) throw error;
        return "sent";
      } else {
        console.error("driver offer push failed", offer.offer_id, result.error ?? result);
        return "failed";
      }
    } catch (error) {
      console.error("driver offer push exception", offer.offer_id, String(error));
      return "failed";
    }
  };
  const outcomes: string[] = [];
  const pending = claims ?? [];
  for (let offset = 0; offset < pending.length; offset += 25) {
    outcomes.push(...await Promise.all(pending.slice(offset, offset + 25).map(processOffer)));
  }
  return json({ processed: pending.length,
    sent: outcomes.filter((value) => value === "sent").length,
    failed: outcomes.filter((value) => value === "failed").length,
    expired: outcomes.filter((value) => value === "expired").length,
    duration_ms: Date.now() - startedAt });
});
