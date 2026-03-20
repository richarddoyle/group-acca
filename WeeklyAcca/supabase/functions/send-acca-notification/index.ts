import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";
import { SignJWT, importPKCS8 } from "https://deno.land/x/jose@v4.14.4/index.ts";

// Supabase automatically injects Deno environment variables
const apnsKeyId = Deno.env.get("APNS_KEY_ID") ?? "";
const apnsTeamId = Deno.env.get("APNS_TEAM_ID") ?? "";
const apnsBundleId = Deno.env.get("APNS_BUNDLE_ID") ?? "com.rudedog-productions.WeeklyAcca";
// The `.p8` key content stored safely in Supabase Secrets as APNS_AUTH_KEY
const apnsAuthKey = Deno.env.get("APNS_AUTH_KEY") ?? "";
const isProduction = Deno.env.get("APNS_ENV") === "production"; // Default to sandbox unless explicitly set to 'production' in Supabase secrets

const apnsHost = isProduction ? "api.push.apple.com" : "api.development.push.apple.com";

serve(async (req: Request) => {
  try {
    // 1. Initialize Supabase Client
    const authHeader = req.headers.get("Authorization")!;
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } }
    );

    // 2. Parse the Trigger Payload
    // Expected payload is from a Postgres Trigger or edge function invocation with body: { record: { ... } }
    const body = await req.json();
    const newWeek = body.record;

    if (!newWeek || !newWeek.group_id) {
      return new Response("No week data provided", { status: 400 });
    }

    // 3. Fetch Group Members
    const { data: members, error: membersError } = await supabaseClient
      .from("members")
      .select("user_id")
      .eq("group_id", newWeek.group_id);

    if (membersError) throw membersError;

    const userIds = members.map((m: any) => m.user_id).filter((id: any) => id !== null);

    if (userIds.length === 0) {
      return new Response("No members in group", { status: 200 });
    }

    // 4. Fetch Profiles with APNs Tokens
    const { data: profiles, error: profilesError } = await supabaseClient
      .from("profiles")
      .select("id, apns_token")
      .in("id", userIds)
      .not("apns_token", "is", null);

    if (profilesError) throw profilesError;

    const tokens = profiles.map((p: any) => p.apns_token).filter((t: any) => t !== null);

    if (tokens.length === 0) {
      return new Response("No members have APNs tokens registered", { status: 200 });
    }

    // 5. Generate APNs JWT
    const privateKey = await importPKCS8(apnsAuthKey, "ES256");
    const token = await new SignJWT({})
      .setProtectedHeader({ alg: "ES256", kid: apnsKeyId })
      .setIssuer(apnsTeamId)
      .setIssuedAt()
      .setExpirationTime("1h")
      .sign(privateKey);

    // 6. Construct the Notification Payload
    const lockTime = new Date(newWeek.start_date).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

    const notificationPayload = {
      aps: {
        alert: {
          title: `New Acca: ${newWeek.title}`,
          body: `Picks for the new accumulator are open! Make sure to lock them in before ${lockTime}.`,
        },
        badge: 1,
        sound: "default",
      },
      weekId: newWeek.id,
      groupId: newWeek.group_id
    };

    // 7. Send to APNs
    // Modern Deno natively supports HTTP/2 via fetch, enabling APNs integration without node-apn
    const results = [];
    const pushID = crypto.randomUUID().toUpperCase();

    for (const deviceToken of tokens) {
      const url = `https://${apnsHost}/3/device/${deviceToken}`;
      const response = await fetch(url, {
        method: "POST",
        headers: {
          "Authorization": `bearer ${token}`,
          "apns-topic": apnsBundleId,
          "apns-push-type": "alert",
          "apns-priority": "10",
          "apns-id": pushID,
          "apns-expiration": "0", // 0 means if device is offline, don't store it forever
          "Content-Type": "application/json"
        },
        body: JSON.stringify(notificationPayload),
      });

      const responseText = await response.text();
      console.log(`APNs Response status for ${deviceToken}:`, response.status, responseText, response.headers);

      results.push({
        token: deviceToken,
        status: response.status,
        message: responseText
      });
    }

    return new Response(JSON.stringify({ success: true, results }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    });

  } catch (error: any) {
    console.error(error);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { "Content-Type": "application/json" },
      status: 500,
    });
  }
});
