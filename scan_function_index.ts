// Edge Function "scan": perantara aman antara aplikasi dan Roboflow.
// - Private API key HANYA ada di Supabase Secrets.
// - Menghormati MODE PEMELIHARAAN (tabel app_settings).
// - Menghitung dan membatasi scan harian per paket (reguler 10, vip 50, premium 100; admin tanpa batas).
//   Tiap hasil yang berhasil diterima = 1 scan. Jika Roboflow gagal, hitungan dikembalikan.

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const sbUrl = Deno.env.get("SUPABASE_URL");
  const svc = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const anon = Deno.env.get("SUPABASE_ANON_KEY") ?? svc;
  const svcHeaders = {
    apikey: svc ?? "",
    Authorization: `Bearer ${svc ?? ""}`,
    "Content-Type": "application/json",
  };
  let refundUser: string | null = null;
  const refund = async () => {
    if (!refundUser || !sbUrl || !svc) return;
    try {
      await fetch(`${sbUrl}/rest/v1/rpc/refund_scan`, {
        method: "POST",
        headers: svcHeaders,
        body: JSON.stringify({ p_user: refundUser }),
      });
    } catch (_) {
      // abaikan
    }
  };

  try {
    // --- 1. Mode pemeliharaan (jika gagal membaca pengaturan, lanjut seperti biasa) ---
    if (sbUrl && svc) {
      try {
        const r = await fetch(`${sbUrl}/rest/v1/app_settings?select=key,value`, { headers: svcHeaders });
        if (r.ok) {
          const rows: { key: string; value: string }[] = await r.json();
          const get = (k: string) => rows.find((x) => x.key === k)?.value ?? "";
          if (get("maintenance") === "on") {
            return json(
              { error: "maintenance", message: get("maintenance_message") || "Fitur scan sedang istirahat sementara." },
              503,
            );
          }
        }
      } catch (_) {
        // abaikan
      }
    }

    // --- 2. Validasi masukan dan konfigurasi ---
    const { image } = await req.json();
    if (!image || typeof image !== "string") {
      return json({ error: "Gambar kosong" }, 400);
    }
    const key = Deno.env.get("ROBOFLOW_API_KEY");
    const model = Deno.env.get("ROBOFLOW_MODEL_ID");
    if (!key || !model) {
      return json({ error: "Secret ROBOFLOW_API_KEY / ROBOFLOW_MODEL_ID belum diisi" }, 500);
    }
    if (!sbUrl || !svc) {
      return json({ error: "config", message: "Konfigurasi server belum lengkap." }, 500);
    }
    const host = Deno.env.get("ROBOFLOW_HOST") ?? "serverless.roboflow.com";
    const conf = Deno.env.get("ROBOFLOW_CONFIDENCE") ?? "40";

    // --- 3. Siapa yang memanggil? ---
    const auth = req.headers.get("Authorization") ?? "";
    const ur = await fetch(`${sbUrl}/auth/v1/user`, { headers: { apikey: anon ?? "", Authorization: auth } });
    if (!ur.ok) {
      return json({ error: "unauthorized", message: "Sesi tidak valid. Silakan masuk lagi." }, 401);
    }
    const user = await ur.json();
    const uid: string = user.id;

    // --- 4. Hitung dan batasi scan harian ---
    const cr = await fetch(`${sbUrl}/rest/v1/rpc/consume_scan`, {
      method: "POST",
      headers: svcHeaders,
      body: JSON.stringify({ p_user: uid }),
    });
    if (!cr.ok) {
      return json({ error: "quota_error", message: "Gagal memeriksa kuota scan. Pastikan SQL tambahan sudah dijalankan." }, 500);
    }
    const q = await cr.json();
    if (!q.allowed) {
      return json(
        { error: "limit", message: `Batas scan harian (${q.limit}) untuk paket ${q.plan} sudah habis. Coba lagi besok.`, quota: q },
        429,
      );
    }
    if (!q.unlimited) refundUser = uid;

    // --- 5. Panggil Roboflow ---
    const url = `https://${host}/${model}?api_key=${encodeURIComponent(key)}&confidence=${conf}`;
    let res: Response;
    try {
      res = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: image,
      });
    } catch (e) {
      await refund();
      return json({ error: String(e) }, 502);
    }
    const text = await res.text();
    if (!res.ok) {
      await refund();
      return new Response(text, {
        status: res.status,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    try {
      const rf = JSON.parse(text);
      rf._quota = { plan: q.plan, used: q.used, limit: q.limit, unlimited: q.unlimited, remaining: q.remaining };
      return json(rf, 200);
    } catch (_) {
      return new Response(text, {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
  } catch (e) {
    await refund();
    return json({ error: String(e) }, 500);
  }
});
