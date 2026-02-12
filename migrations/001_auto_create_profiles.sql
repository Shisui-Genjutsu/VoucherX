-- Migration: Auto-create user profiles on signup
-- This migration adds a trigger to automatically create a profile entry
-- when a new user signs up through Supabase Auth

-- Step 1: Create function to handle new user creation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, username, avatar_url, voucher_coins)
  VALUES (
    new.id,
    COALESCE(new.raw_user_meta_data->>'full_name', 'User'),
    COALESCE(
      new.raw_user_meta_data->>'username',
      COALESCE(new.email, 'user_' || substr(new.id::text, 1, 8))
    ),
    new.raw_user_meta_data->>'avatar_url',
    100
  );
  RETURN new;
END;
$$;

-- Step 2: Create trigger to execute the function on new user signup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- Step 3: Backfill profiles for existing users who don't have one
INSERT INTO public.profiles (id, full_name, username, voucher_coins)
SELECT 
  au.id,
  COALESCE(au.raw_user_meta_data->>'full_name', 'User'),
  COALESCE(
    au.raw_user_meta_data->>'username',
    COALESCE(au.email, 'user_' || substr(au.id::text, 1, 8))
  ),
  100
FROM auth.users au
LEFT JOIN public.profiles p ON au.id = p.id
WHERE p.id IS NULL
ON CONFLICT (id) DO NOTHING;

-- Step 4: Verify the migration
DO $$
DECLARE
  users_without_profiles INTEGER;
BEGIN
  SELECT COUNT(*) INTO users_without_profiles
  FROM auth.users au
  LEFT JOIN public.profiles p ON au.id = p.id
  WHERE p.id IS NULL;
  
  IF users_without_profiles > 0 THEN
    RAISE WARNING 'Warning: % users still do not have profiles', users_without_profiles;
  ELSE
    RAISE NOTICE 'Success: All users now have profiles';
  END IF;
END $$;
