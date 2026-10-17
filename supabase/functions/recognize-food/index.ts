import { authenticateUser } from "./auth.mjs";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

type Recognition = {
  food_name: string;
  estimated_weight_g: number;
  confidence: number;
  provider: string;
  model: string;
  raw?: string;
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json; charset=utf-8" },
  });
}

function parseRecognition(content: string, provider: string, model: string): Recognition {
  const match = content.match(/\{[\s\S]*\}/);
  if (!match) throw new Error("视觉模型未返回 JSON");
  const value = JSON.parse(match[0]);
  const foodName = String(value.food_name || "").trim();
  const weight = Number(value.estimated_weight_g);
  const confidence = Number(value.confidence);
  if (!foodName || !Number.isFinite(weight) || weight <= 0) {
    throw new Error("视觉模型返回的食物名称或重量无效");
  }
  return {
    food_name: foodName.slice(0, 80),
    estimated_weight_g: Math.min(Math.round(weight), 5000),
    confidence: Number.isFinite(confidence)
      ? Math.max(0, Math.min(1, confidence))
      : 0,
    provider,
    model,
    raw: content.slice(0, 4000),
  };
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") return json({ error: "仅支持 POST" }, 405);

  const authentication = await authenticateUser(request, {
    supabaseUrl: Deno.env.get("SUPABASE_URL"),
    anonKey: Deno.env.get("SUPABASE_ANON_KEY"),
  });
  if (!authentication.ok) {
    return json({ error: authentication.error }, authentication.status);
  }

  const apiKey = Deno.env.get("VISION_API_KEY");
  const baseUrl = (Deno.env.get("VISION_API_BASE") ||
    "https://dashscope.aliyuncs.com/compatible-mode/v1").replace(/\/$/, "");
  const model = Deno.env.get("VISION_MODEL") || "qwen-vl-plus";
  const provider = Deno.env.get("VISION_PROVIDER") || "dashscope";
  if (!apiKey) return json({ error: "服务端未配置 VISION_API_KEY" }, 503);

  try {
    const body = await request.json();
    const image = typeof body.imageBase64 === "string" ? body.imageBase64 : "";
    if (!/^data:image\/(jpeg|png|webp);base64,/i.test(image)) {
      return json({ error: "仅支持 JPEG、PNG 或 WebP 的 base64 图片" }, 400);
    }
    if (image.length > 8_000_000) return json({ error: "图片过大" }, 413);

    const upstream = await fetch(`${baseUrl}/chat/completions`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model,
        temperature: 0,
        messages: [{
          role: "user",
          content: [
            { type: "image_url", image_url: { url: image } },
            {
              type: "text",
              text: "识别图中主要食物并估算可食用重量。只返回 JSON：" +
                '{"food_name":"中文名称","estimated_weight_g":100,"confidence":0.8}',
            },
          ],
        }],
      }),
    });
    if (!upstream.ok) {
      const detail = (await upstream.text()).slice(0, 300);
      console.error("Vision API error", upstream.status, detail);
      return json({ error: `视觉服务请求失败（HTTP ${upstream.status}）` }, 502);
    }
    const payload = await upstream.json();
    const content = payload?.choices?.[0]?.message?.content;
    if (typeof content !== "string") throw new Error("视觉模型响应结构无效");
    return json(parseRecognition(content, provider, model));
  } catch (error) {
    console.error("recognize-food", error);
    return json({ error: error instanceof Error ? error.message : "识别失败" }, 500);
  }
});
