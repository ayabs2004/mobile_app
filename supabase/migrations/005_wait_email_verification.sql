-- =============================================================================
-- Migration: Wait for email verification before creating profile
-- =============================================================================

-- 1. Drop existing trigger on auth.users if it exists
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- 2. Modify the trigger function to handle both INSERT (if email already confirmed)
--    and UPDATE (when email becomes confirmed)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  -- If email confirmation is not required or already confirmed at signup
  IF TG_OP = 'INSERT' AND NEW.email_confirmed_at IS NOT NULL THEN
    INSERT INTO public.profiles (id, full_name, phone, role)
    VALUES (
      NEW.id,
      NEW.raw_user_meta_data->>'full_name',
      NEW.raw_user_meta_data->>'phone',
      'customer'
    ) ON CONFLICT (id) DO NOTHING;
  
  -- If email gets confirmed later via update
  ELSIF TG_OP = 'UPDATE' AND OLD.email_confirmed_at IS NULL AND NEW.email_confirmed_at IS NOT NULL THEN
    INSERT INTO public.profiles (id, full_name, phone, role)
    VALUES (
      NEW.id,
      NEW.raw_user_meta_data->>'full_name',
      NEW.raw_user_meta_data->>'phone',
      'customer'
    ) ON CONFLICT (id) DO NOTHING;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Create the trigger on auth.users for INSERT and UPDATE
CREATE TRIGGER on_auth_user_created
  AFTER INSERT OR UPDATE ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
