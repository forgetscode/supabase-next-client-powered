import { cookies, headers } from 'next/headers';
import { createBrowserSupabaseClient, createServerComponentSupabaseClient } from '@supabase/auth-helpers-nextjs';
import { Database } from "#/types/supabase";

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
