import { Database } from "#/types/supabase";
import { SupabaseClient } from "@supabase/supabase-js";
import { TenantSchemaTemplateName } from "#/constants/meta";
const { useSupabaseClient } = require("@supabase/auth-helpers-react");

/**
 *  @desc
 *  Remove the type for useSupabaseClient from type file in "@supabase/auth-helpers-react" using patch-package,
 *  so that it cannot be imported.
 *
 *  In its place, we export this one, so that it automatically uses the types for our database.
 *  @example
 *  const supabase = useSupabase();
 *
 *  // which is an abstraction over this:
 *  const supabase = useSupabaseClient<Database>();
 */
export const useSupabase = (): SupabaseClient<Database, TenantSchemaTemplateName> =>
  useSupabaseClient();


