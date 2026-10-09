export function setInMemorySessionFromSupabaseSession(session) {
  if (!session) return null;
  if (!session.access_token) return null;
  return {
    access_token: session.access_token,
    refresh_token: session.refresh_token,
  };
}

export async function safeSignOut(supabaseAuth) {
  if (!supabaseAuth) return;
  try {
    await supabaseAuth.auth.signOut();
  } catch (_) {
    // ignore
  }
}

export async function checkExistingAdminSession({ supabase, supabaseAuth }) {
  if (!supabaseAuth || !supabase) return { ok: false, reason: "missing_clients" };
  try {
    const { data: { session } } = await supabaseAuth.auth.getSession();
    if (!session) return { ok: false, reason: "no_session" };

    const { data: profile } = await supabase
      .from("profiles")
      .select("role, full_name")
      .eq("id", session.user.id)
      .single();

    // ทีมแอดมิน: superadmin (admin) หรือ staff — สิทธิ์จริงโหลดต่อด้วย my_admin_access
    if (profile?.role !== "admin" && profile?.role !== "staff") return { ok: false, reason: "not_admin" };
    return { ok: true, session, user: session.user, profile };
  } catch (_) {
    return { ok: false, reason: "error" };
  }
}
