

drop function if exists create_tenant_schema;
  create or replace function create_tenant_schema(new_tenant_name text, input_owner_profile_id uuid) returns void as $$
  declare
    tenant_uuid uuid;
    schema_path text;
  begin
    -- generate a random uuid for the tenant
    select gen_random_uuid() into tenant_uuid;
    -- get a string version of the uuid for use as the schema name
    schema_path := tenant_uuid::text;

    create schema schema_path;
    set search_path to schema_path;

    grant usage, create on schema schema_path to tenant_admin;

    -- function to check if user has permission to CRUD role tables
    drop function if exists check_can_operate_on_role;
      create or replace function check_can_operate_on_role(in input_profile_id uuid, in operation text) returns boolean as $$
      declare
        mapping_role_id uuid;
        role_record record;
        permission_result boolean;
      begin
        permission_result := false;
        for mapping_role_id in (select role_profile_mapping.role_id from role_profile_mapping where role_profile_mapping.profile_id = input_profile_id) loop
          -- find all role records associated with the current role_id
          for role_record in (select * from role where role.id = mapping_role_id) loop
            if operation = 'SELECT' then
              permission_result := role_record.can_read_roles;
            elseif operation = 'UPDATE' then
              permission_result := role_record.can_update_roles;
            elseif operation = 'INSERT' then
              permission_result := role_record.can_insert_roles;
            elseif operation = 'DELETE' then
              permission_result := role_record.can_delete_roles;
            else
              raise exception 'got bad operation type';
            end if;
            if permission_result = true then
              return true;
            end if;
          end loop;
        end loop;
        return false;
      end; $$ language plpgsql security definer set search_path = schema_path;

    -- function to check permissions associated with the user's roles
    drop function if exists check_role_permission;
      create or replace function check_role_permission(in input_profile_id uuid, in wanted_table_name text, in operation text) returns boolean as $$
      declare
        mapping_role_id uuid;
        role_permission_record record;
        permission_result boolean;
      begin
        permission_result := false;
        for mapping_role_id in (select role_profile_mapping.role_id from role_profile_mapping where role_profile_mapping.profile_id = input_profile_id) loop
          -- find all role_permission records associated with the current role_id
          for role_permission_record in (select * from role_permission where role_permission.role_id = mapping_role_id and role_permission.table_name = wanted_table_name) loop
            if operation = 'SELECT' then
              permission_result := role_permission_record.can_read;
            elseif operation = 'UPDATE' then
              permission_result := role_permission_record.can_update;
            elseif operation = 'INSERT' then
              permission_result := role_permission_record.can_create;
            elseif operation = 'DELETE' then
              permission_result := role_permission_record.can_delete;
            else
              raise exception 'got bad operation type';
            end if;
            if permission_result = true then
              return true;
            end if;
          end loop;
        end loop;
        return false;
      end; $$ language plpgsql security definer set search_path = schema_path;

    create type if not exists check_profile_permission_result AS ENUM ('whitelisted', 'blacklisted', 'none');
    -- function to check profile permissions when doing update/insert/delete on a row
    drop function if exists check_profile_permission;
      create or replace function check_profile_permission(in input_profile_id uuid, in wanted_table_name text, in operation text, in input_row_id uuid) returns check_profile_permission_result as $$
      declare
        profile_permission_item record;
        permission_result boolean;
      begin
        permission_result := false;
        -- there should only ever be one profile_permission row with the same profile_id and row_id columns
        if exists (select 1 from profile_permission where profile_permission.profile_id = input_profile_id and profile_permission.row_id = input_row_id and profile_permission.table_name = wanted_table_name) then
          select * into profile_permission_item from profile_permission where profile_permission.profile_id = input_profile_id and profile_permission.row_id = input_row_id and profile_permission.table_name = wanted_table_name;
          if operation = 'SELECT' then
            permission_result := profile_permission_item.can_read;
          elseif operation = 'UPDATE' then
            permission_result := profile_permission_item.can_read;
          elseif operation = 'INSERT' then
            permission_result := profile_permission_item.can_read;
          elseif operation = 'DELETE' then
            permission_result := profile_permission_item.can_read;
          else
            raise exception 'got bad operation type';
          end if;
          if permission_result = true then
            return 'whitelisted';
          else
            return 'blacklisted';
          end if;
        end if;
        return 'none';
      end; $$ language plpgsql security definer set search_path = schema_path;

    -- function which combines logic for checking permissions based on profile-level permissions and role-level permissions.
    -- if profile_permissions has a row describing a permission, it takes precedence and the query should be allowed or
    -- disallowed according to what it specifies. if there is no relevant profile_permission, check role permissions.
    drop function if exists check_permissions;
      create or replace function check_permissions(in input_profile_id uuid, in wanted_table_name text, in operation text, in row_id uuid) returns boolean as $$
      declare
        profile_permission_result check_profile_permission_result;
      begin
        profile_permission_result := check_profile_permission(input_profile_id, wanted_table_name, operation, row_id);
        if profile_permission_result = 'whitelisted' then
          return true;
        elseif profile_permission_result = 'blacklisted' then
          return false;
        else
          return check_role_permission(input_profile_id, wanted_table_name, operation);
        end if;
      end; $$ language plpgsql security definer set search_path = schema_path;

    -- create row in meta tenant table to store information about the created schema
    insert into meta.tenant(id, tenant_name, schema_path, owner_profile_id)
    values (tenant_uuid, new_tenant_name, schema_path, input_owner_profile_id);

    -- create a mapping between the owner of the tenant and the tenant
    insert into meta.tenant_profile_mapping(profile_id, tenant_id)
    values (input_owner_profile_id, tenant_uuid);

    drop table if exists role;
      create table role (
        id uuid primary key default uuid_generate_v4(),
        role_name text,
        role_description text,

        can_create_roles boolean not null default false,
        can_read_roles boolean not null default false,
        can_update_roles boolean not null default false,
        can_delete_roles boolean not null default false,
        canConfigureTenant boolean not null default false
      );
    meta.insert_table_meta("role", "role");

    -- table holding rows with one permission for a table in one role
    drop table if exists role_permission;
      create table role_permission (
        id uuid primary key default uuid_generate_v4(),
        role_id uuid not null,
        table_name text not null,
        can_create boolean not null,
        can_read boolean not null,
        can_update boolean not null,
        can_delete boolean not null
      );
    meta.insert_table_meta("role_permission", "role");

    -- mapping between user profiles and roles
    drop table if exists role_profile_mapping;
      create table role_profile_mapping(
        id uuid primary key default uuid_generate_v4(),
        profile_id uuid not null,
        role_id uuid not null
      );
    meta.insert_table_meta("role_profile_mapping", "role");

    -- table holding one whitelist or blacklist permission for one user profile for one individual record
    drop table if exists profile_permission;
      create table profile_permission (
        id uuid primary key default uuid_generate_v4(),
        profile_id uuid not null,
        table_name text not null,
        row_id uuid not null unique,
        can_create boolean not null, -- TODO: does can_create make sense for this?
        can_read boolean not null,
        can_update boolean not null,
        can_delete boolean not null
      );
    meta.insert_table_meta("profile_permission", "role");

    alter table role
      enable row level security;

    alter table role_permission
      add constraint fk_role_id foreign key (role_id) references role(id),
      enable row level security;

    alter table role_profile_mapping
      add constraint fk_profile_id foreign key (profile_id) references meta.profile(id),
      add constraint fk_role_id foreign key (role_id) references role(id),
      enable row level security;

    alter table profile_permission
      add constraint fk_profile_permission_profile_id foreign key (profile_id) references meta.profile(id),
      enable row level security;
-- TODO: implement
--     -- table holding
--     drop table if exists group;
--       create table group (
--         id uuid primary key default uuid_generate_v4(),
--         group_name text,
--         group_description text
--       );

--  https://www.npmjs.com/package/to-json-schema
--  https://www.npmjs.com/package/json-schema-to-typescript
--  for each table type, query the json_schema_store to see if it is a table with a json schema property
--  if it is, take the json schema and generate typescript types with it

    -- TODO: write function which checks if this already exists or not before inserting
    -- TODO: this is just a few properties from one of the qbo objects to test inserting json strings into columns
    insert into meta.json_schema_store(table_name, table_column, json_schema) values ('qbo_customer', 'table_data', E'{
       "type": "object",
       "properties": {
         "PrimaryEmailAddr": {
           "type": "object",
           "properties": {
             "Address": {
               "type": "string"
             }
           }
         },
         "SyncToken": {
           "type": "string"
         }
       },
       "required": ["PrimaryEmailAddr"],
       "additionalProperties": false
     }');

    drop table if exists qbo_customer;
      create table qbo_customer (
         id uuid primary key default uuid_generate_v4(),
         table_data jsonp not null,
           check (
             json_matches_schema (
               schema := '{
                 "type": "object",
                 "properties": {
                   "PrimaryEmailAddr": {
                     "type": "object",
                     "properties": {
                       "Address": {
                         "type": "string"
                       }
                     }
                   },
                   "SyncToken": {
                     "type": "string"
                   }
                 },
                 "required": ["PrimaryEmailAddr"],
                 "additionalProperties": false
               }',
               instance := metadata
             )
           )
      )
    meta.insert_table_meta("qbo_customer", "auto");

    alter table qbo_customer
      enable row level security;

    -- policies for setting permissions for operating on roles
    drop policy if exists "role_security";
    create policy "role_security" on role for all
      using (check_can_operate_on_role(auth.uid(), TG_OP))
      with check (check_can_operate_on_role(auth.uid(), TG_OP));
    drop policy if exists "role_permission_security";
    create policy "role_permission_security" on role_permission for all
      using (check_can_operate_on_role(auth.uid(), TG_OP))
      with check (check_can_operate_on_role(auth.uid(), TG_OP));
    drop policy if exists "role_profile_mapping_security";
    create policy "role_profile_mapping_security" on role_profile_mapping for all
      using (check_can_operate_on_role(auth.uid(), TG_OP))
      with check (check_can_operate_on_role(auth.uid(), TG_OP));
    drop policy if exists "profile_permission_security";
    create policy "profile_permission_security" on profile_permission for all
      using (check_can_operate_on_role(auth.uid(), TG_OP))
      with check (check_can_operate_on_role(auth.uid(), TG_OP));

    -- auto generate policies for tables which have the auto flag
    do $$
      declare
        table_name text;
      begin
        for table_name in (select table_name from tenant_schema_table_info where table_type = 'auto') loop
          execute format(E'
            drop policy if exists "%S_security";
            create policy "%S_security" on %I for all
             using (id is not null and check_permissions(auth.uid(), \'%S\', TG_OP, id))
             with check (id is not null and check_permissions(auth.uid(), \'%S\', TG_OP, id));
          ', table_name, table_name, table_name, table_name, table_name);
        end loop;
      end; $$
  end; $$ language plpgsql;

















