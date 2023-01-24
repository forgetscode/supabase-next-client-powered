import { headers, cookies } from 'next/headers';
import { createServerComponentSupabaseClient } from '@supabase/auth-helpers-nextjs';
import { Database } from "#/types/supabase";
import { createBrowserSupabaseClient } from '@supabase/auth-helpers-nextjs';

export const createSupabaseServerClient = () =>
  createServerComponentSupabaseClient<Database>({
    headers,
    cookies
  });

export const createSupabaseBrowserClient = () =>
  createBrowserSupabaseClient({
    supabaseUrl: process.env.NEXT_PUBLIC_SUPABASE_URL,
    supabaseKey: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
  });
