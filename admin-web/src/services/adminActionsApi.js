export async function callAdminAction({ supabaseAuth, supabaseUrl, supabaseAnonKey, actionBody, inMemorySession, onUnauthorized }) {
  let session = null;
  try {
    session = (await supabaseAuth.auth.getSession())?.data?.session;
  } catch (_) {
    session = null;
  }

  if (!session?.access_token && inMemorySession?.access_token) {
    try {
      const restored = await supabaseAuth.auth.setSession({
        access_token: inMemorySession.access_token,
        refresh_token: inMemorySession.refresh_token,
      });
      session = restored?.data?.session || session;
    } catch (_) {
      session = session;
    }
  }

  if (!session?.access_token) {
    throw new Error("missing_session");
  }

  try {
    const expiresAtMs = (session.expires_at || 0) * 1000;
    const shouldRefresh = !expiresAtMs || Date.now() > expiresAtMs - 60_000;
    if (shouldRefresh) {
      const refreshed = await supabaseAuth.auth.refreshSession();
      session = refreshed?.data?.session || session;
    }
  } catch (_) {
    session = session;
  }

  const res = await fetch(`${supabaseUrl}/functions/v1/admin-actions`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${session.access_token}`,
      apikey: supabaseAnonKey,
    },
    body: JSON.stringify(actionBody),
  });

  let data = null;
  try {
    data = await res.json();
  } catch (_) {
    data = null;
  }

  if (!res.ok) {
    if (res.status === 401) {
      if (typeof onUnauthorized === "function") {
        await onUnauthorized(data);
      }
      throw new Error(`unauthorized${data?.error ? `:${data.error}` : ""}`);
    }
    throw new Error(data?.error || `http_${res.status}`);
  }

  return data;
}
