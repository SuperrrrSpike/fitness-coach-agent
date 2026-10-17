export async function authenticateUser(request, options = {}) {
  const authorization = request.headers.get("authorization") || "";
  if (!/^Bearer\s+\S+$/i.test(authorization)) {
    return { ok: false, status: 401, error: "请先登录" };
  }

  const supabaseUrl = options.supabaseUrl || "";
  const apiKey = request.headers.get("apikey") || options.anonKey || "";
  if (!supabaseUrl || !apiKey) {
    return { ok: false, status: 503, error: "认证服务未配置" };
  }

  const fetcher = options.fetcher || fetch;
  try {
    const response = await fetcher(`${supabaseUrl.replace(/\/$/, "")}/auth/v1/user`, {
      method: "GET",
      headers: {
        Authorization: authorization,
        apikey: apiKey,
      },
    });
    if (!response.ok) {
      return { ok: false, status: 401, error: "登录状态无效或已过期" };
    }
    return { ok: true, status: 200, error: "" };
  } catch {
    return { ok: false, status: 503, error: "认证服务暂时不可用" };
  }
}
