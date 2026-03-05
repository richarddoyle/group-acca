// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";
import { SignJWT, importPKCS8 } from "https://deno.land/x/jose@v4.14.4/index.ts";

const apnsKeyId = Deno.env.get("APNS_KEY_ID") ?? "";
const apnsTeamId = Deno.env.get("APNS_TEAM_ID") ?? "";
const apnsBundleId = Deno.env.get("APNS_BUNDLE_ID") ?? "com.rudedog-productions.WeeklyAcca";
// The `.p8` key content should be stored safely in Supabase Secrets as APNS_AUTH_KEY
const apnsAuthKey = Deno.env.get("APNS_AUTH_KEY") ?? "";
const isProduction = true; // Set to false if using APNs Sandbox

const apnsHost = isProduction ? "api.push.apple.com" : "api.development.push.apple.com";

serve(async (req) => {
  try {
    // 1. Initialize Supabase Client
    const authHeader = req.headers.get("Authorization")!;
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } }
    );

    // 2. Parse the Trigger Payload
    // Expected payload is from a Postgres Trigger on the `weeks` table
    const body = await req.json();
    const newWeek = body.record; // The newly inserted row

    if (!newWeek || !newWeek.group_id) {
      return new Response("No week data provided", { status: 400 });
    }

    // 3. Fetch Group Members (excluding the creator if possible, but for now we fetch all)
    // We only want members who have an APNs token.
    const { data: members, error: membersError } = await supabaseClient
      .from("members")
      .select("user_id")
      .eq("group_id", newWeek.group_id);

    if (membersError) throw membersError;

    const userIds = members.map(m => m.user_id).filter(id => id !== null);

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

    const tokens = profiles.map(p => p.apns_token).filter(t => t !== null);

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
    // Convert newWeek.start_date to a readable "Lock Time" string
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
    // Note: Edge Functions have some limitations with direct HTTP/2 required by APNs.
    // Deno's fetch() supports HTTP/2 implicitly. We can try standard fetch first.

    const results = [];

    for (const deviceToken of tokens) {
      const url = `https://${apnsHost}/3/device/${deviceToken}`;
      const response = await fetch(url, {
        method: "POST",
        headers: {
          "Authorization": `bearer ${token}`,
          "apns-topic": apnsBundleId,
          "apns-push-type": "alert",
          "apns-priority": "10",
        },
        body: JSON.stringify(notificationPayload),
      });

      results.push({
        token: deviceToken,
        status: response.status,
        message: await response.text()
      });
    }

    return new Response(JSON.stringify({ success: true, results }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    });

  } catch (error) {
    console.error(error);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { "Content-Type": "application/json" },
      status: 500,
    });
  }
});
