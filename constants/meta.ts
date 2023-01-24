import { Database } from "#/types/supabase";

/** @desc title for browser tab */
export const title = "Client Powered";

/** @desc Icon for browser tab */
export const icon = "https://raw.githubusercontent.com/praveenpuglia/tailwind-breeze/master/assets/logo.svg";

/** @desc Name of the unused schema in our database that we use as the template for all other tenant schemas. */
export type TenantSchemaTemplateName<T extends keyof Database = "public"> = "public";
