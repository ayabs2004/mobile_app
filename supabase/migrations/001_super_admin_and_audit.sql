-- =============================================================================
-- Migration : Super Admin, sous-admins et journal d'audit
-- À exécuter dans le SQL Editor Supabase (Dashboard > SQL)
-- =============================================================================

-- 1. Étendre les rôles autorisés
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE profiles
  ADD CONSTRAINT profiles_role_check
  CHECK (role IN ('customer', 'admin', 'super_admin'));

-- 2. Promouvoir VOTRE compte en super admin (remplacez l'UUID)
-- UPDATE profiles SET role = 'super_admin' WHERE id = 'VOTRE-UUID-ICI';

-- 3. Table d'audit
CREATE TABLE IF NOT EXISTS admin_audit_log (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id      uuid REFERENCES profiles(id) ON DELETE SET NULL,
  action        text NOT NULL CHECK (action IN ('create', 'update', 'delete')),
  entity_type   text NOT NULL,
  entity_id     uuid,
  entity_label  text,
  details       jsonb,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_actor ON admin_audit_log(actor_id);
CREATE INDEX IF NOT EXISTS idx_audit_created ON admin_audit_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_entity ON admin_audit_log(entity_type, entity_id);

ALTER TABLE admin_audit_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "super_admin_read_audit" ON admin_audit_log;
CREATE POLICY "super_admin_read_audit"
  ON admin_audit_log FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'super_admin'
    )
  );

-- 4. Fonction générique de logging (triggers sur les tables de contenu)
CREATE OR REPLACE FUNCTION log_admin_audit()
RETURNS TRIGGER AS $$
DECLARE
  v_actor_role text;
  v_label text;
  v_entity_id uuid;
BEGIN
  SELECT role INTO v_actor_role FROM profiles WHERE id = auth.uid();

  -- Ne journaliser que les actions des admins / super admins
  IF v_actor_role IS NULL OR v_actor_role NOT IN ('admin', 'super_admin') THEN
    IF TG_OP = 'DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
  END IF;

  IF TG_OP = 'DELETE' THEN
    v_entity_id := OLD.id;
    v_label := COALESCE(
      to_jsonb(OLD) ->> 'full_name',
      to_jsonb(OLD) ->> 'name',
      v_entity_id::text
    );
    INSERT INTO admin_audit_log (actor_id, action, entity_type, entity_id, entity_label)
    VALUES (auth.uid(), 'delete', TG_TABLE_NAME, v_entity_id, v_label);
    RETURN OLD;

  ELSIF TG_OP = 'UPDATE' THEN
    v_entity_id := NEW.id;
    v_label := COALESCE(
      to_jsonb(NEW) ->> 'full_name',
      to_jsonb(NEW) ->> 'name',
      v_entity_id::text
    );
    INSERT INTO admin_audit_log (actor_id, action, entity_type, entity_id, entity_label, details)
    VALUES (
      auth.uid(), 'update', TG_TABLE_NAME, v_entity_id, v_label,
      jsonb_build_object('before', to_jsonb(OLD), 'after', to_jsonb(NEW))
    );
    RETURN NEW;

  ELSIF TG_OP = 'INSERT' THEN
    v_entity_id := NEW.id;
    v_label := COALESCE(
      to_jsonb(NEW) ->> 'full_name',
      to_jsonb(NEW) ->> 'name',
      v_entity_id::text
    );
    INSERT INTO admin_audit_log (actor_id, action, entity_type, entity_id, entity_label)
    VALUES (auth.uid(), 'create', TG_TABLE_NAME, v_entity_id, v_label);
    RETURN NEW;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Triggers sur les tables de contenu (adapter si une table n'existe pas)
DROP TRIGGER IF EXISTS audit_players ON players;
CREATE TRIGGER audit_players
  AFTER INSERT OR UPDATE OR DELETE ON players
  FOR EACH ROW EXECUTE FUNCTION log_admin_audit();

DROP TRIGGER IF EXISTS audit_teams ON teams;
CREATE TRIGGER audit_teams
  AFTER INSERT OR UPDATE OR DELETE ON teams
  FOR EACH ROW EXECUTE FUNCTION log_admin_audit();

DROP TRIGGER IF EXISTS audit_coaches ON coaches;
CREATE TRIGGER audit_coaches
  AFTER INSERT OR UPDATE OR DELETE ON coaches
  FOR EACH ROW EXECUTE FUNCTION log_admin_audit();

DROP TRIGGER IF EXISTS audit_academies ON academies;
CREATE TRIGGER audit_academies
  AFTER INSERT OR UPDATE OR DELETE ON academies
  FOR EACH ROW EXECUTE FUNCTION log_admin_audit();

DROP TRIGGER IF EXISTS audit_neighborhood_teams ON neighborhood_teams;
CREATE TRIGGER audit_neighborhood_teams
  AFTER INSERT OR UPDATE OR DELETE ON neighborhood_teams
  FOR EACH ROW EXECUTE FUNCTION log_admin_audit();

-- 6. Mettre à jour prevent_role_change pour autoriser super_admin via service role uniquement
-- (si le trigger existe déjà, le recréer)
CREATE OR REPLACE FUNCTION prevent_role_change()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.role IS DISTINCT FROM NEW.role THEN
    -- Seule la service_role (Edge Functions) peut changer le rôle
    IF current_setting('request.jwt.claims', true)::json->>'role' != 'service_role' THEN
      RAISE EXCEPTION 'Modification du rôle interdite côté client';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_prevent_role_change ON profiles;
CREATE TRIGGER trg_prevent_role_change
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION prevent_role_change();
