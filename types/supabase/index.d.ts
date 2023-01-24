import { SupabaseClient } from "@supabase/supabase-js";
import { Database } from "./supabase";
import * as _supabase_supabase_js_dist_module_lib_types from "@supabase/supabase-js/dist/module/lib/types";
import { TenantSchemaTemplateName } from "#/constants/meta";
export * from "./supabase"
declare module "./supabase" {
  export type TenantDB<SchemaName extends keyof Database> =
    SupabaseClient<Database, SchemaName, Database[SchemaName] extends _supabase_supabase_js_dist_module_lib_types.GenericSchema ? Database[SchemaName] : any>;
  export type DatabaseTables = Database[TenantSchemaTemplateName]["Tables"];

  /** @desc Convenience type for selecting the type of a table*/
  export type TableSelector<
    TableName extends keyof DatabaseTables
  > = DatabaseTables[TableName];

  export type TableRow<
    TableName extends keyof DatabaseTables,
    RemoveNull extends boolean = false
  > = ExcludeTypeFromProps<TableSelector<TableName>["Row"], null, RemoveNull>;

  export type TableInsert<
    TableName extends keyof DatabaseTables,
    RemoveNull extends boolean = false
  > = ExcludeTypeFromProps<TableSelector<TableName>["Insert"], null, RemoveNull>;

  export type TableUpdate<
    TableName extends keyof DatabaseTables,
    RemoveNull extends boolean = false
  > = ExcludeTypeFromProps<TableSelector<TableName>["Update"], null, RemoveNull>;
}
