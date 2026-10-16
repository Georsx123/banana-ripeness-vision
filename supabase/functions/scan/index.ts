// Edge Function "scan": perantara aman antara aplikasi dan Roboflow.
// - Private API key HANYA ada di Supabase Secrets, tidak pernah ada di aplikasi / GitHub.
// - Menghormati MODE PEMELIHARAAN (tabel app_settings): saat aktif, scan ditolak (HTTP 503).

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
  try {
    // --- Cek mode pemeliharaan (jika gagal membaca pengaturan, lanjut seperti biasa) ---
    const sbUrl = Deno.env.get("SUPABASE_URL");
    const sbKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (sbUrl && sbKey) {
      try {
        const r = await fetch(`${sbUrl}/rest/v1/app_settings?select=key,value`, {
          headers: { apikey: sbKey, Authorization: `Bearer ${sbKey}` },
        });
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

    const { image } = await req.json();
    if (!image || typeof image !== "string") {
      return json({ error: "Gambar kosong" }, 400);
    }

    const key = Deno.env.get("ROBOFLOW_API_KEY");
    const model = Deno.env.get("ROBOFLOW_MODEL_ID");
    if (!key || !model) {
      return json({ error: "Secret ROBOFLOW_API_KEY / ROBOFLOW_MODEL_ID belum diisi" }, 500);
    }
    const host = Deno.env.get("ROBOFLOW_HOST") ?? "serverless.roboflow.com";
    const conf = Deno.env.get("ROBOFLOW_CONFIDENCE") ?? "40";

    const url = `https://${host}/${model}?api_key=${encodeURIComponent(key)}&confidence=${conf}`;
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: image,
    });
    const text = await res.text();
    return new Response(text, {
      status: res.status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
