import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

type JsonResponse = Record<string, unknown>;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "DELETE, OPTIONS",
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "DELETE") {
    return json({ error: "Method not allowed" }, 405);
  }

  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseURL || !anonKey || !serviceRoleKey) {
    return json({ error: "Server is not configured" }, 500);
  }

  const authorization = request.headers.get("Authorization") ?? "";
  if (!authorization.toLowerCase().startsWith("bearer ")) {
    return json({ error: "Missing bearer token" }, 401);
  }

  const userClient = createClient(supabaseURL, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) {
    return json({ error: "Invalid bearer token" }, 401);
  }

  const userID = userData.user.id;
  const admin = createClient(supabaseURL, serviceRoleKey, {
    auth: { persistSession: false },
  });

  const tables = [
    ["moderation_reports", "reporter"],
    ["moderation_reports", "reported"],
    ["reactions", "from_user"],
    ["reactions", "to_user"],
    ["activity_events", "user_id"],
    ["user_blocks", "blocker"],
    ["user_blocks", "blocked"],
    ["friendships", "requested_by"],
    ["friendships", "user_a"],
    ["friendships", "user_b"],
    ["profile_privacy", "user_id"],
    ["public_profiles", "user_id"],
  ] as const;

  for (const [table, column] of tables) {
    const { error } = await admin.from(table).delete().eq(column, userID);
    if (error) {
      console.error(`Account delete failed for ${table}.${column}`, error);
      return json({ error: "Failed to delete account data" }, 500);
    }
  }

  const { error: deleteUserError } = await admin.auth.admin.deleteUser(userID);
  if (deleteUserError) {
    console.error("Auth user delete failed", deleteUserError);
    return json({ error: "Failed to delete auth user" }, 500);
  }

  return json({ ok: true });
});

function json(body: JsonResponse, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json; charset=utf-8",
    },
  });
}
