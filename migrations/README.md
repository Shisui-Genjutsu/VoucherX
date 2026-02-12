# Database Migrations

This directory contains SQL migration files for the VoucherX database.

## How to Run Migrations

### Using Supabase Dashboard

1. Go to your Supabase project dashboard
2. Navigate to **SQL Editor** in the left sidebar
3. Click **New Query**
4. Copy the contents of the migration file
5. Paste into the SQL editor
6. Click **Run** to execute the migration

### Using Supabase CLI

```bash
# Make sure you're in the project directory
cd /path/to/VoucherX

# Run a specific migration
supabase db execute --file migrations/001_auto_create_profiles.sql
```

## Migration Files

### `001_auto_create_profiles.sql`

**Purpose**: Automatically create user profiles when users sign up

**What it does**:
1. Creates a PostgreSQL function `handle_new_user()` that inserts a profile entry
2. Creates a trigger `on_auth_user_created` that fires when a new user signs up
3. Backfills profiles for existing users who don't have one
4. Verifies that all users now have profiles

**When to run**: 
- Required before users can add vouchers
- Fixes the foreign key constraint error: `vouchers_seller_id_fkey`

**Safe to re-run**: Yes, uses `ON CONFLICT DO NOTHING` to prevent duplicates

## Migration Order

Migrations should be run in numerical order:
1. `001_auto_create_profiles.sql`
2. (Future migrations will be numbered sequentially)

## Rollback

If you need to rollback the profile creation trigger:

```sql
-- Remove the trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Remove the function
DROP FUNCTION IF EXISTS public.handle_new_user();
```

**⚠️ Warning**: Do not delete profiles that have associated vouchers, as this will cascade delete the vouchers.

## Testing Migrations

After running a migration, verify it worked:

```sql
-- Check if trigger exists
SELECT trigger_name, event_manipulation, event_object_table
FROM information_schema.triggers
WHERE trigger_name = 'on_auth_user_created';

-- Check if all users have profiles
SELECT COUNT(*) as users_without_profiles
FROM auth.users au
LEFT JOIN public.profiles p ON au.id = p.id
WHERE p.id IS NULL;
-- Should return 0
```
