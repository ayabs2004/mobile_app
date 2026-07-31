-- =============================================================================
-- Migration : RLS profiles + gestion des rôles
-- À exécuter dans le SQL Editor Supabase (Dashboard > SQL)
-- =============================================================================

-- 1. Activer RLS sur profiles (si pas déjà fait)
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- 2. Fonction helper (évite la récursion RLS pour lire le rôle)
CREATE OR REPLACE FUNCTION public.is_admin_or_super_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE id = auth.uid()
      AND role IN ('admin', 'super_admin')
  );
$$;

-- 3. Policies SELECT sur profiles
DROP POLICY IF EXISTS "users_read_own_profile" ON profiles;
CREATE POLICY "users_read_own_profile"
  ON profiles FOR SELECT
  USING (auth.uid() = id);

DROP POLICY IF EXISTS "admins_read_all_profiles" ON profiles;
CREATE POLICY "admins_read_all_profiles"
  ON profiles FOR SELECT
  USING (public.is_admin_or_super_admin());

-- 4. Policy UPDATE : chacun peut modifier son profil (sauf le rôle, bloqué par trigger)
DROP POLICY IF EXISTS "users_update_own_profile" ON profiles;
CREATE POLICY "users_update_own_profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- =============================================================================
-- COMMANDES MANUELLES (copier-coller selon votre besoin)
-- =============================================================================

-- A) Vérifier votre rôle actuel (remplacez l'UUID)
-- SELECT id, full_name, role FROM profiles WHERE id = 'VOTRE-UUID-ICI';

-- B) Vous promouvoir super admin (à faire UNE FOIS pour votre compte)
-- UPDATE profiles SET role = 'super_admin' WHERE id = 'VOTRE-UUID-ICI';

-- C) Rétrograder des comptes super_admin en sous-admin (role = 'admin')
--    Gardez au moins UN super_admin (le vôtre) !
-- UPDATE profiles
-- SET role = 'admin'
-- WHERE role = 'super_admin'
--   AND id != 'VOTRE-UUID-ICI';

-- D) Rétrograder TOUS les admins (y compris super_admin) en sous-admin
--    Puis re-promouvoir uniquement votre compte en super_admin :
-- UPDATE profiles SET role = 'admin' WHERE role IN ('admin', 'super_admin');
-- UPDATE profiles SET role = 'super_admin' WHERE id = 'VOTRE-UUID-ICI';

-- E) Lister tous les comptes admin / super_admin
-- SELECT id, full_name, role, created_at FROM profiles
-- WHERE role IN ('admin', 'super_admin')
-- ORDER BY role, full_name;
