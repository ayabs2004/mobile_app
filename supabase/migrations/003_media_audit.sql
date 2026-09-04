-- =============================================================================
-- Migration : audit des médias (photos / vidéos)
-- =============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'media'
  ) THEN
    CREATE TABLE public.media (
      id uuid NOT NULL DEFAULT gen_random_uuid(),
      entity_type text,
      entity_id uuid,
      media_type text,
      url text,
      thumbnail_url text,
      caption text,
      display_order integer DEFAULT 0,
      is_cover boolean DEFAULT false,
      created_at timestamp without time zone DEFAULT now(),
      CONSTRAINT media_pkey PRIMARY KEY (id)
    );
  END IF;

  ALTER TABLE public.media
    ADD COLUMN IF NOT EXISTS entity_type text,
    ADD COLUMN IF NOT EXISTS entity_id uuid,
    ADD COLUMN IF NOT EXISTS media_type text,
    ADD COLUMN IF NOT EXISTS url text,
    ADD COLUMN IF NOT EXISTS thumbnail_url text,
    ADD COLUMN IF NOT EXISTS caption text,
    ADD COLUMN IF NOT EXISTS display_order integer DEFAULT 0,
    ADD COLUMN IF NOT EXISTS is_cover boolean DEFAULT false,
    ADD COLUMN IF NOT EXISTS created_at timestamp without time zone DEFAULT now();
END $$;

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
        'parent_id', to_jsonb(OLD) ->> 'entity_id',
        'media_type', to_jsonb(OLD) ->> 'media_type',
        'url', to_jsonb(OLD) ->> 'url',
        'is_cover', to_jsonb(OLD) ->> 'is_cover'
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
        'before', to_jsonb(OLD),
        'after', to_jsonb(NEW),
        'parent_type', to_jsonb(NEW) ->> 'entity_type',
        'parent_id', to_jsonb(NEW) ->> 'entity_id',
        'media_type', to_jsonb(NEW) ->> 'media_type',
        'url', to_jsonb(NEW) ->> 'url',
        'thumbnail_url', to_jsonb(NEW) ->> 'thumbnail_url',
        'caption', to_jsonb(NEW) ->> 'caption',
        'is_cover', to_jsonb(NEW) ->> 'is_cover'
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
        'parent_type', to_jsonb(NEW) ->> 'entity_type',
        'parent_id', to_jsonb(NEW) ->> 'entity_id',
        'media_type', to_jsonb(NEW) ->> 'media_type',
        'url', to_jsonb(NEW) ->> 'url',
        'thumbnail_url', to_jsonb(NEW) ->> 'thumbnail_url',
        'caption', to_jsonb(NEW) ->> 'caption',
        'is_cover', to_jsonb(NEW) ->> 'is_cover'
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

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'media'
  ) THEN
    IF EXISTS (
      SELECT 1
      FROM pg_trigger
      WHERE tgname = 'audit_media'
    ) THEN
      EXECUTE 'DROP TRIGGER audit_media ON public.media';
    END IF;

    EXECUTE 'CREATE TRIGGER audit_media
      AFTER INSERT OR UPDATE OR DELETE ON public.media
      FOR EACH ROW EXECUTE FUNCTION log_admin_audit()';
  END IF;
END $$;
