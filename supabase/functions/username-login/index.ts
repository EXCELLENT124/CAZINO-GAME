import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import postgres from "npm:postgres@3.4.7";

const sql = postgres(requiredEnv("SUPABASE_DB_URL"), {
  max: 1,
  prepare: false,
});

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);
  try {
    const body = await request.json();
    const url = requiredEnv("SUPABASE_URL");
    const publishableKey = namedKey("SUPABASE_PUBLISHABLE_KEYS") ??
      Deno.env.get("SUPABASE_ANON_KEY");
    if (!publishableKey) {
      throw new Error("Supabase function credentials are unavailable");
    }

    if (body.action === "availability") {
      const username = String(body.username ?? "").trim().toLowerCase();
      if (!/^[a-z0-9_]{3,20}$/.test(username)) {
        return json({ available: false, error: "Username must use 3-20 letters, numbers, or underscores" }, 400);
      }
      const [result] = await sql<{ taken: boolean }[]>`
        select exists(
          select 1 from public.profiles where username = ${username}
        ) as taken
      `;
      return json({ available: !result.taken });
    }

    const identifier = String(body.identifier ?? "").trim().toLowerCase();
    const password = String(body.password ?? "");
    if (!identifier || !password) return json({ error: "Enter username/email and password" }, 400);
    let email = identifier;
    if (!identifier.includes("@")) {
      const users = await sql<{ email: string }[]>`
        select u.email
        from public.profiles p
        join auth.users u on u.id = p.id
        where p.username = ${identifier}
        limit 1
      `;
      if (!users[0]?.email) return json({ error: "Invalid username or password" }, 400);
      email = users[0].email;
    }
    const authResponse = await fetch(`${url}/auth/v1/token?grant_type=password`, {
      method: "POST",
      headers: { "Content-Type": "application/json", apikey: publishableKey },
      body: JSON.stringify({ email, password }),
    });
    return new Response(await authResponse.text(), {
      status: authResponse.status,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("username-login failed", error);
    return json({ error: "Unable to sign in at this time" }, 500);
  }
});

function json(value: unknown, status = 200) {
  return new Response(JSON.stringify(value), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

function requiredEnv(name: string) {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing ${name}`);
  return value;
}

function namedKey(name: string) {
  const raw = Deno.env.get(name);
  if (!raw) return null;
  const keys = JSON.parse(raw) as Record<string, string>;
  return keys.default ?? Object.values(keys)[0] ?? null;
}
