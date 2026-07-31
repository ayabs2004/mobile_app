// Edge Function Supabase : gestion des comptes admin / sous-admin
// Déployer avec : supabase functions deploy admin-create-user
//
// Actions supportées :
//   create_sub_admin  { email, fullName, password, phone? } — super_admin only
//   update_sub_admin  { userId, fullName }          — super_admin only
//   delete_sub_admin  { userId }                      — super_admin only
//   set_role          { userId, role }                — super_admin only (admin|customer)
//   (legacy)          { email, fullName }             — alias create_sub_admin

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonError("Non authentifié", 401);
    }

    const supabaseUser = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const {
      data: { user: caller },
      error: authError,
    } = await supabaseUser.auth.getUser();

    if (authError || !caller) {
      return jsonError("Non authentifié", 401);
    }

    const { data: callerProfile } = await supabaseAdmin
      .from("profiles")
      .select("role")
      .eq("id", caller.id)
      .single();

    const callerRole = callerProfile?.role;
    const isSuperAdmin = callerRole === "super_admin";

    const body = await req.json();
    const action = body.action ?? (body.email ? "create_sub_admin" : null);

    if (!action) {
      return jsonError("Action manquante", 400);
    }

    // ── Créer un sous-admin (compte direct avec mot de passe) ──
    if (action === "create_sub_admin") {
      if (!isSuperAdmin) {
        return jsonError("Seul le super admin peut créer des sous-admins", 403);
      }

      const { email, fullName, password, phone } = body;
      if (!email) return jsonError("Email requis", 400);
      if (typeof password !== "string" || password.length < 6) {
        return jsonError("Mot de passe requis (minimum 6 caractères)", 400);
      }

      const userMetadata: Record<string, string> = {
        full_name: fullName ?? "",
      };
      if (phone && typeof phone === "string" && phone.trim()) {
        userMetadata.phone = phone.trim();
      }

      const { data: createData, error: createError } =
        await supabaseAdmin.auth.admin.createUser({
          email,
          password,
          email_confirm: true,
          user_metadata: userMetadata,
        });

      if (createError || !createData.user) {
        return jsonError(createError?.message ?? "Échec de la création du compte", 400);
      }

      const userId = createData.user.id;

      const { error: profileError } = await supabaseAdmin.from("profiles").upsert({
        id: userId,
        full_name: fullName ?? null,
        role: "admin",
      });

      if (profileError) {
        await supabaseAdmin.auth.admin.deleteUser(userId);
        return jsonError(
          "Compte créé mais échec du profil : " + profileError.message,
          500,
        );
      }

      await supabaseAdmin.from("admin_audit_log").insert({
        actor_id: caller.id,
        action: "create",
        entity_type: "sub_admin",
        entity_id: userId,
        entity_label: fullName ?? email,
        details: { email },
      });

      return jsonOk({ userId });
    }

    // ── Modifier un sous-admin ──
    if (action === "update_sub_admin") {
      if (!isSuperAdmin) {
        return jsonError("Seul le super admin peut modifier des sous-admins", 403);
      }

      const { userId, fullName } = body;
      if (!userId) return jsonError("userId requis", 400);

      const { data: target } = await supabaseAdmin
        .from("profiles")
        .select("role, full_name")
        .eq("id", userId)
        .single();

      if (!target || target.role !== "admin") {
        return jsonError("Utilisateur introuvable ou non modifiable", 404);
      }

      if (fullName) {
        await supabaseAdmin
          .from("profiles")
          .update({ full_name: fullName })
          .eq("id", userId);

        await supabaseAdmin.auth.admin.updateUserById(userId, {
          user_metadata: { full_name: fullName },
        });
      }

      await supabaseAdmin.from("admin_audit_log").insert({
        actor_id: caller.id,
        action: "update",
        entity_type: "sub_admin",
        entity_id: userId,
        entity_label: fullName ?? target.full_name,
      });

      return jsonOk({});
    }

    // ── Supprimer un sous-admin ──
    if (action === "delete_sub_admin") {
      if (!isSuperAdmin) {
        return jsonError("Seul le super admin peut supprimer des sous-admins", 403);
      }

      const { userId } = body;
      if (!userId) return jsonError("userId requis", 400);

      if (userId === caller.id) {
        return jsonError("Vous ne pouvez pas supprimer votre propre compte", 400);
      }

      const { data: target } = await supabaseAdmin
        .from("profiles")
        .select("role, full_name")
        .eq("id", userId)
        .single();

      if (!target || target.role !== "admin") {
        return jsonError("Utilisateur introuvable ou non supprimable", 404);
      }

      await supabaseAdmin.from("admin_audit_log").insert({
        actor_id: caller.id,
        action: "delete",
        entity_type: "sub_admin",
        entity_id: userId,
        entity_label: target.full_name,
      });

      await supabaseAdmin.auth.admin.deleteUser(userId);

      return jsonOk({});
    }

    // ── Changer le rôle (legacy, super_admin only) ──
    if (action === "set_role") {
      if (!isSuperAdmin) {
        return jsonError("Seul le super admin peut changer les rôles", 403);
      }

      const { userId, role } = body;
      if (!userId || !role) return jsonError("userId et role requis", 400);
      if (role === "super_admin") {
        return jsonError("Impossible de promouvoir en super admin via l'app", 403);
      }

      await supabaseAdmin
        .from("profiles")
        .update({ role })
        .eq("id", userId);

      return jsonOk({});
    }

    return jsonError("Action inconnue", 400);
  } catch (err) {
    return jsonError(String(err), 500);
  }
});

function jsonOk(data: Record<string, unknown>) {
  return new Response(JSON.stringify(data), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function jsonError(message: string, status: number) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
