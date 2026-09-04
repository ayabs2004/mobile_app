-- =============================================================================
-- Migration 004 : ajouter entity_name (nom du joueur/coach) dans les détails
--                 d'audit des médias (INSERT, UPDATE et DELETE).
-- Structure identique à la fonction d'origine — seul ajout : le champ
-- 'entity_name' via une sous-requête scalaire dans chaque jsonb_build_object.
-- Exécuter ce script dans l'éditeur SQL de Supabase.
-- =============================================================================

CREATE OR REPLACE FUNCTION log_admin_audit()
RETURNS TRIGGER AS $$
DECLARE
  v_actor_role text;
  v_label text;
  v_entity_id uuid;
  v_details jsonb;
BEGIN
  SELECT role INTO v_actor_role FROM profiles WHERE id = auth.uid();

  -- Ne journaliser que les actions des admins / super admins
  IF v_actor_role IS NULL OR v_actor_role NOT IN ('admin', 'super_admin') THEN
    IF TG_OP = 'DELETE' THEN
      RETURN OLD;
    ELSE
      RETURN NEW;
    END IF;
  END IF;

  IF TG_OP = 'DELETE' THEN
    v_entity_id := OLD.id;
    v_label := COALESCE(
      to_jsonb(OLD) ->> 'full_name',
      to_jsonb(OLD) ->> 'name',
      to_jsonb(OLD) ->> 'caption',
      to_jsonb(OLD) ->> 'url',
      v_entity_id::text
    );

    v_details := CASE
      WHEN TG_TABLE_NAME = 'media' THEN jsonb_build_object(
        'parent_type', to_jsonb(OLD) ->> 'entity_type',
        'parent_id',   to_jsonb(OLD) ->> 'entity_id',
        'entity_name', CASE
          WHEN to_jsonb(OLD) ->> 'entity_type' = 'player' THEN
            (SELECT full_name FROM players WHERE id = (to_jsonb(OLD) ->> 'entity_id')::uuid)
          WHEN to_jsonb(OLD) ->> 'entity_type' = 'coach' THEN
            (SELECT full_name FROM coaches WHERE id = (to_jsonb(OLD) ->> 'entity_id')::uuid)
          ELSE NULL
        END,
        'media_type',  to_jsonb(OLD) ->> 'media_type',
        'url',         to_jsonb(OLD) ->> 'url',
        'is_cover',    to_jsonb(OLD) ->> 'is_cover'
      )
      ELSE NULL
    END;

    INSERT INTO admin_audit_log (actor_id, action, entity_type, entity_id, entity_label, details)
    VALUES (
      auth.uid(), 'delete', TG_TABLE_NAME, v_entity_id, v_label, v_details
    );
    RETURN OLD;

  ELSIF TG_OP = 'UPDATE' THEN
    v_entity_id := NEW.id;
    v_label := COALESCE(
      to_jsonb(NEW) ->> 'full_name',
      to_jsonb(NEW) ->> 'name',
      to_jsonb(NEW) ->> 'caption',
      to_jsonb(NEW) ->> 'url',
      v_entity_id::text
    );

    v_details := CASE
      WHEN TG_TABLE_NAME = 'media' THEN jsonb_build_object(
        'before',        to_jsonb(OLD),
        'after',         to_jsonb(NEW),
        'parent_type',   to_jsonb(NEW) ->> 'entity_type',
        'parent_id',     to_jsonb(NEW) ->> 'entity_id',
        'entity_name',   CASE
          WHEN to_jsonb(NEW) ->> 'entity_type' = 'player' THEN
            (SELECT full_name FROM players WHERE id = (to_jsonb(NEW) ->> 'entity_id')::uuid)
          WHEN to_jsonb(NEW) ->> 'entity_type' = 'coach' THEN
            (SELECT full_name FROM coaches WHERE id = (to_jsonb(NEW) ->> 'entity_id')::uuid)
          ELSE NULL
        END,
        'media_type',    to_jsonb(NEW) ->> 'media_type',
        'url',           to_jsonb(NEW) ->> 'url',
        'thumbnail_url', to_jsonb(NEW) ->> 'thumbnail_url',
        'caption',       to_jsonb(NEW) ->> 'caption',
        'is_cover',      to_jsonb(NEW) ->> 'is_cover'
      )
      ELSE jsonb_build_object('before', to_jsonb(OLD), 'after', to_jsonb(NEW))
    END;

    INSERT INTO admin_audit_log (actor_id, action, entity_type, entity_id, entity_label, details)
    VALUES (
      auth.uid(), 'update', TG_TABLE_NAME, v_entity_id, v_label, v_details
    );
    RETURN NEW;

  ELSIF TG_OP = 'INSERT' THEN
    v_entity_id := NEW.id;
    v_label := COALESCE(
      to_jsonb(NEW) ->> 'full_name',
      to_jsonb(NEW) ->> 'name',
      to_jsonb(NEW) ->> 'caption',
      to_jsonb(NEW) ->> 'url',
      v_entity_id::text
    );

    v_details := CASE
      WHEN TG_TABLE_NAME = 'media' THEN jsonb_build_object(
        'parent_type',   to_jsonb(NEW) ->> 'entity_type',
        'parent_id',     to_jsonb(NEW) ->> 'entity_id',
        'entity_name',   CASE
          WHEN to_jsonb(NEW) ->> 'entity_type' = 'player' THEN
            (SELECT full_name FROM players WHERE id = (to_jsonb(NEW) ->> 'entity_id')::uuid)
          WHEN to_jsonb(NEW) ->> 'entity_type' = 'coach' THEN
            (SELECT full_name FROM coaches WHERE id = (to_jsonb(NEW) ->> 'entity_id')::uuid)
          ELSE NULL
        END,
        'media_type',    to_jsonb(NEW) ->> 'media_type',
        'url',           to_jsonb(NEW) ->> 'url',
        'thumbnail_url', to_jsonb(NEW) ->> 'thumbnail_url',
        'caption',       to_jsonb(NEW) ->> 'caption',
        'is_cover',      to_jsonb(NEW) ->> 'is_cover'
      )
      ELSE NULL
    END;

    INSERT INTO admin_audit_log (actor_id, action, entity_type, entity_id, entity_label, details)
    VALUES (
      auth.uid(), 'create', TG_TABLE_NAME, v_entity_id, v_label, v_details
    );
    RETURN NEW;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
