const TOKEN = "c2c_token";

export function getToken() {
  return localStorage.getItem(TOKEN);
}

export function setToken(token) {
  if (token) localStorage.setItem(TOKEN, token);
  else localStorage.removeItem(TOKEN);
}

export async function api(path, opts = {}) {
  const headers = { ...(opts.headers || {}) };
  const token = getToken();
  if (token) headers.Authorization = `Bearer ${token}`;
  if (opts.body && !(opts.body instanceof FormData) && !headers["Content-Type"]) {
    headers["Content-Type"] = "application/json";
  }
  const res = await fetch(path, {
    ...opts,
    headers,
    credentials: "include",
    body: opts.body instanceof FormData ? opts.body : opts.body ? JSON.stringify(opts.body) : undefined,
  });
  const text = await res.text();
  let data = null;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = { detail: text };
  }
  if (!res.ok) {
    const detail = data?.detail;
    const msg = typeof detail === "string" ? detail : Array.isArray(detail) ? detail[0]?.msg : res.statusText;
    throw new Error(msg || "Request failed");
  }
  return data;
}
