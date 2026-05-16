// @ts-nocheck
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-cron-secret",
};

const cronSecret = Deno.env.get("AUTO_SHOP_SCHEDULE_SECRET") ?? "";

function isShopOpenNow(merchant: Record<string, unknown>, bangkokNow: Date): boolean {
  const openStr = (merchant.shop_open_time as string | null)?.trim();
  const closeStr = (merchant.shop_close_time as string | null)?.trim();
  if (!openStr || !closeStr) return !!(merchant.shop_status);

  const openParts = openStr.split(":");
  const closeParts = closeStr.split(":");
  if (openParts.length < 2 || closeParts.length < 2) return !!(merchant.shop_status);

  const openHour = parseInt(openParts[0]);
  const openMinute = parseInt(openParts[1]);
  const closeHour = parseInt(closeParts[0]);
  const closeMinute = parseInt(closeParts[1]);
  if (isNaN(openHour) || isNaN(openMinute) || isNaN(closeHour) || isNaN(closeMinute)) {
    return !!(merchant.shop_status);
  }

  const nowMinutes = bangkokNow.getHours() * 60 + bangkokNow.getMinutes();
  const openMinutes = openHour * 60 + openMinute;
  const closeMinutes = closeHour * 60 + closeMinute;

  const withinHours =
    openMinutes <= closeMinutes
      ? nowMinutes >= openMinutes && nowMinutes < closeMinutes
      : nowMinutes >= openMinutes || nowMinutes < closeMinutes;

  const rawDays = merchant.shop_open_days;
  if (Array.isArray(rawDays) && rawDays.length > 0) {
    const weekdayKeys = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"];
    // getDay() returns 0=Sun,1=Mon,...,6=Sat; Bangkok weekday
    const dayIndex = bangkokNow.getDay() === 0 ? 6 : bangkokNow.getDay() - 1;
    const todayKey = weekdayKeys[dayIndex];
    const allowedDays = new Set(rawDays.map((d) => String(d).toLowerCase().trim()));
    if (allowedDays.size > 0 && !allowedDays.has(todayKey)) return false;
  }

  return withinHours;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const secret = req.headers.get("x-cron-secret");
  if (!cronSecret || secret !== cronSecret) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const supabase = createClient(supabaseUrl, serviceRoleKey);

  // Bangkok time = UTC+7
  const nowUtc = new Date();
  const bangkokNow = new Date(nowUtc.getTime() + 7 * 60 * 60 * 1000);

  const { data: merchants, error } = await supabase
    .from("profiles")
    .select("id, shop_status, shop_open_time, shop_close_time, shop_open_days, shop_auto_schedule_enabled")
    .eq("shop_auto_schedule_enabled", true);

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const results: { id: string; changed: boolean; shouldBeOpen: boolean }[] = [];

  for (const merchant of merchants ?? []) {
    const shouldBeOpen = isShopOpenNow(merchant, bangkokNow);
    const currentStatus = merchant.shop_status === true || merchant.shop_status === 1;
    if (shouldBeOpen !== currentStatus) {
      // Update both shop_status and is_online together to keep them in sync (ISSUE-048)
      const { error: updateError } = await supabase
        .from("profiles")
        .update({ shop_status: shouldBeOpen, is_online: shouldBeOpen })
        .eq("id", merchant.id);
      results.push({ id: merchant.id, changed: !updateError, shouldBeOpen });
    }
  }

  return new Response(
    JSON.stringify({
      ok: true,
      processed: merchants?.length ?? 0,
      changed: results.length,
      bangkokTime: bangkokNow.toISOString(),
      results,
    }),
    { headers: { ...corsHeaders, "Content-Type": "application/json" } },
  );
});
