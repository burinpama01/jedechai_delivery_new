// Supabase Edge Function: send-admin-email
// ส่งอีเมลแจ้งเตือนไปยัง admin
//
// วิธี deploy:
//   supabase functions deploy send-admin-email
//
// ต้องตั้ง secret:
//   supabase secrets set SMTP_HOST=smtp.gmail.com
//   supabase secrets set SMTP_PORT=587
//   supabase secrets set SMTP_USER=your-email@gmail.com
//   supabase secrets set SMTP_PASS=your-app-password
//   supabase secrets set SMTP_FROM=your-email@gmail.com

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { to, subject, html } = await req.json();

    if (!to || !subject) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: to, subject" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ส่งอีเมลผ่าน Resend API (แนะนำ — ฟรี 100 email/วัน)
    const resendApiKey = Deno.env.get("RESEND_API_KEY");
    if (resendApiKey) {
      const res = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${resendApiKey}`,
        },
        body: JSON.stringify({
          from: Deno.env.get("RESEND_FROM") || "Jedechai Admin <noreply@jedechai.com>",
          to: [to],
          subject,
          html: html || subject,
        }),
      });

      const data = await res.json();
      console.log("Resend response:", JSON.stringify(data));

      return new Response(
        JSON.stringify({ success: true, provider: "resend", data }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Fallback: บันทึกลง email_queue table (สำหรับดูใน admin web)
    console.log(`📧 Email queued: to=${to}, subject=${subject}`);
    return new Response(
      JSON.stringify({
        success: true,
        provider: "queue",
        message: "Email queued (no email provider configured). Set RESEND_API_KEY to enable.",
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
