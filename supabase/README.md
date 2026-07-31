# Supabase — Super Admin & Audit

## Déploiement

### 1. Migrations SQL

1. Ouvrez **Supabase Dashboard → SQL Editor**
2. Exécutez `migrations/001_super_admin_and_audit.sql`
3. Exécutez `migrations/002_profiles_rls_and_roles.sql`
4. **Promouvez votre compte** (remplacez l'UUID) :

```sql
UPDATE profiles SET role = 'super_admin' WHERE id = 'VOTRE-UUID-ICI';
```

Pour trouver votre UUID : **Authentication → Users → copier l'ID**

#### Rétrograder des admins en sous-admins

En base, **sous-admin = `role = 'admin'`**, super admin = `role = 'super_admin'`.

```sql
-- Rétrograder tous les super_admin SAUF vous
UPDATE profiles
SET role = 'admin'
WHERE role = 'super_admin'
  AND id != 'VOTRE-UUID-ICI';
```

### 2. Edge Function

Si vous utilisez la CLI Supabase :

```bash
supabase functions deploy admin-create-user
```

Sinon, copiez le contenu de `functions/admin-create-user/index.ts` dans le dashboard Supabase (**Edge Functions → admin-create-user → Edit**).

### 3. Vérification

- Votre profil doit avoir `role = 'super_admin'`
- Les sous-admins créés auront `role = 'admin'`
- Le journal `admin_audit_log` se remplit automatiquement via les triggers PostgreSQL

## Rôles

| Rôle | Droits |
|------|--------|
| `super_admin` | Tout + gestion sous-admins + historique |
| `admin` | CRUD contenu uniquement |
| `customer` | Utilisateur standard |
