-- function to check if user has permission to CRUD role tables
drop function if exists check_can_operate_on_role;
  create or replace function check_can_operate_on_role(
    in schema_name text,
    in input_profile_id uuid,
    in operation text
  ) returns boolean as $$
  declare
    mapping_role_id uuid;
    role_record record;
    permission_result boolean;
  begin
    if not has_tenant_schema_access(schema_name) then
      return false;
    end if;
    execute format('set search_path to %I', schema_name);
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
  end; $$ language plpgsql security definer;


-- function to check permissions associated with the user's roles
drop function if exists check_role_permission;
  create or replace function check_role_permission(
    in schema_name text,
    in input_profile_id uuid,
    in wanted_table_name text,
    in operation text
  ) returns boolean as $$
  declare
    mapping_role_id uuid;
    role_permission_record record;
    permission_result boolean;
  begin
    if not has_tenant_schema_access(schema_name) then
      return false;
    end if;
    execute format('set search_path to %I', schema_name);
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
  end; $$ language plpgsql security definer;


create type if not exists check_profile_permission_result AS ENUM ('whitelisted', 'blacklisted', 'none');

-- function to check profile permissions when doing update/insert/delete on a row
drop function if exists check_profile_permission;
  create or replace function check_profile_permission(
    in schema_name text,
    in input_profile_id uuid,
    in wanted_table_name text,
    in operation text,
    in input_row_id uuid
  ) returns check_profile_permission_result as $$
  declare
    profile_permission_item record;
    permission_result boolean;
  begin
    if not has_tenant_schema_access(schema_name) then
      return false;
    end if;
    execute format('set search_path to %I', schema_name);
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
  end; $$ language plpgsql security definer;

-- function which combines logic for checking permissions based on profile-level permissions and role-level permissions.
-- if profile_permissions has a row describing a permission, it takes precedence and the query should be allowed or
-- disallowed according to what it specifies. if there is no relevant profile_permission, check role permissions.
drop function if exists check_permissions;
  create or replace function check_permissions(
    in schema_name text,
    in input_profile_id uuid,
    in wanted_table_name text,
    in operation text,
    in row_id uuid
  ) returns boolean as $$
  declare
--    is_allowed_on_schema boolean;
    profile_permission_result check_profile_permission_result;
  begin
    if not has_tenant_schema_access(schema_name) then
      return false;
    elseif id is null then
      return false;
    end if;
    execute format('set search_path to %I', schema_name);
--    is_allowed_on_schema := has_tenant_schema_access(schema_name)
    profile_permission_result := check_profile_permission(input_profile_id, wanted_table_name, operation, row_id);
    if profile_permission_result = 'whitelisted' then
      return true;
    elseif profile_permission_result = 'blacklisted' then
      return false;
    else
      return check_role_permission(input_profile_id, wanted_table_name, operation);
    end if;
  end; $$ language plpgsql security definer;


drop function if exists create_tenant_schema;
  create or replace function create_tenant_schema(
    in new_tenant_name text,
    in input_owner_profile_id uuid
  ) returns void as $$
  declare
    tenant_uuid uuid;
    schema_path text;
  begin
    -- generate a random uuid for the tenant
    select gen_random_uuid() into tenant_uuid;

    -- convert uuid into a valid string for a schema_name
    schema_path := concat('_', replace(tenant_uuid::text, '-', ''), '_');

    execute format('create schema %I', schema_path);
    execute format('set search_path to %I', schema_path);
    execute format('grant usage, create on schema %I to tenant_admin', schema_path);

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
    meta.insert_table_meta('role', 'role');

    -- TODO: implement per row_id level whitelist/blacklist for this
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
    meta.insert_table_meta('role_permission', 'role');

    -- mapping between user profiles and roles
    drop table if exists role_profile_mapping;
      create table role_profile_mapping(
        id uuid primary key default uuid_generate_v4(),
        profile_id uuid not null,
        role_id uuid not null
      );
    meta.insert_table_meta('role_profile_mapping', 'role');

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
    meta.insert_table_meta('profile_permission', 'role');

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

    drop table if exists qbo_customer_info;
      create table qbo_customer_info (
         id uuid primary key default uuid_generate_v4(),
         table_data jsonp not null,
           check (
             json_matches_schema (
               schema := '{"title":"CompanyInfo","description":"https://developer.intuit.com/app/developer/qbo/docs/api/accounting/all-entities/companyinfo","type":"object","properties":{"Id":{"type":"string"},"SyncToken":{"type":"string"},"CompanyName":{"type":"string"},"CompanyAddr":{"type":"object","properties":{"Id":{"type":"string"},"PostalCode":{"type":"string"},"City":{"type":"string"},"Country":{"type":"string"},"Line5":{"type":"string"},"Line4":{"type":"string"},"Line3":{"type":"string"},"Line2":{"type":"string"},"Line1":{"type":"string"},"Lat":{"type":"string"},"Long":{"type":"string"},"CountrySubDivisionCode":{"type":"string"}},"required":["Id"],"additionalProperties":false},"LegalAddr":{"type":"object","properties":{"Id":{"type":"string"},"PostalCode":{"type":"string"},"City":{"type":"string"},"Country":{"type":"string"},"Line5":{"type":"string"},"Line4":{"type":"string"},"Line3":{"type":"string"},"Line2":{"type":"string"},"Line1":{"type":"string"},"Lat":{"type":"string"},"Long":{"type":"string"},"CountrySubDivisionCode":{"type":"string"}},"required":["Id"],"additionalProperties":false},"SupportedLanguages":{"type":"string"},"Country":{"type":"string"},"Email":{"type":"object","properties":{"Address":"string"},"additionalProperties":false},"WebAddr":{"type":"object","properties":{"URI":"string"},"additionalProperties":false},"NameValue":{"type":"array","items":{"type":"object","properties":{"Name":{"type":"string"},"Value":{"type":"string"}},"additionalProperties":false}},"FiscalYearStartMonth":{"type":"string"},"CustomerCommunicationAddr":{"type":"object","properties":{"Id":{"type":"string"},"PostalCode":{"type":"string"},"City":{"type":"string"},"Country":{"type":"string"},"Line5":{"type":"string"},"Line4":{"type":"string"},"Line3":{"type":"string"},"Line2":{"type":"string"},"Line1":{"type":"string"},"Lat":{"type":"string"},"Long":{"type":"string"},"CountrySubDivisionCode":{"type":"string"}},"required":["Id"],"additionalProperties":false},"PrimaryPhone":{"type":"object","properties":{"FreeFormNumber":{"type":"string"},"additionalProperties":false}},"LegalName":{"type":"string"},"MetaData":{"type":"object","properties":{"CreateTime":{"type":"string"},"LastUpdatedTime":{"type":"string"}},"additionalProperties":false},"CompanyStartDate":{"type":"string"},"domain":{"type":"string"},"sparse":{"type":"boolean"}},"required":["Id"],"additionalProperties":false}',
               instance := metadata
             )
           )
      );
    -- TODO: is it possible for the tenant_schema_table_info table to be virtual and only exist within this function context?
    meta.insert_table_meta('qbo_customer_info', 'general');

    drop table if exists qbo_customer;
      create table qbo_customer (
         id uuid primary key default uuid_generate_v4(),
         table_data jsonp not null,
           check (
             json_matches_schema (
               schema := '{"title":"Customer","description":"https://developer.intuit.com/app/developer/qbo/docs/api/accounting/all-entities/customer","type":"object","properties":{"Id":{"type":"string"},"SyncToken":{"type":"string"},"DisplayName":{"type":"string"},"Title":{"type":"string"},"GivenName":{"type":"string"},"MiddleName":{"type":"string"},"Suffix":{"type":"string"},"FamilyName":{"type":"string"},"PrimaryEmailAddr":{"type":"object","properties":{"Address":{"type":"string"}},"additionalProperties":false},"ResaleNum":{"type":"string"},"SecondaryTaxIdentifier":{"type":"string"},"ARAccountRef":{"type":"object","properties":{"value":{"type":"string"},"name":{"type":"string"}},"required":["value"],"additionalProperties":false},"DefaultTaxCodeRef":{"type":"object","properties":{"value":{"type":"string"},"name":{"type":"string"}},"required":["value"],"additionalProperties":false},"PreferredDeliveryMethod":{"type":"string"},"GSTIN":{"type":"string"},"SalesTermRef":{"type":"object","properties":{"value":{"type":"string"},"name":{"type":"string"}},"required":["value"],"additionalProperties":false},"CustomerTypeRef":{"type":"object","properties":{"value":{"type":"string"}},"required":["value"],"additionalProperties":false},"Fax":{"type":"object","properties":{"FreeFormNumber":{"type":"string"},"additionalProperties":false}},"BusinessNumber":{"type":"string"},"BillWithParent":{"type":"boolean"},"CurrencyRef":{"type":"object","properties":{"value":{"type":"string"},"name":{"type":"string"}},"required":["value"],"additionalProperties":false},"Mobile":{"type":"object","properties":{"FreeFormNumber":{"type":"string"},"additionalProperties":false}},"Job":{"type":"boolean"},"BalanceWithJobs":{"type":"number"},"PrimaryPhone":{"type":"object","properties":{"FreeFormNumber":{"type":"string"}},"additionalProperties":false},"OpenBalanceDate":{"type":"object","properties":{"date":{"type":"string"}},"additionalProperties":false},"Taxable":{"type":"boolean"},"AlternatePhone":{"type":"object","properties":{"FreeFormNumber":{"type":"string"}},"additionalProperties":false},"MetaData":{"type":"object","properties":{"CreateTime":{"type":"string"},"LastUpdatedTime":{"type":"string"}},"additionalProperties":false},"ParentRef":{"type":"object","properties":{"value":{"type":"string"},"name":{"type":"string"}},"required":["value"],"additionalProperties":false},"Notes":{"type":"string"},"WebAddr":{"type":"object","properties":{"URI":{"type":"string"}},"additionalProperties":false},"Active":{"type":"boolean"},"CompanyName":{"type":"string"},"Balance":{"type":"number"},"ShipAddr":{"type":"object","properties":{"Id":{"type":"string"},"PostalCode":{"type":"string"},"City":{"type":"string"},"Country":{"type":"string"},"Line5":{"type":"string"},"Line4":{"type":"string"},"Line3":{"type":"string"},"Line2":{"type":"string"},"Line1":{"type":"string"},"Lat":{"type":"string"},"Long":{"type":"string"},"CountrySubDivisionCode":{"type":"string"}},"required":["Id"],"additionalProperties":false},"PaymentMethodRef":{"type":"object","properties":{"value":{"type":"string"},"name":{"type":"string"}},"required":["value"],"additionalProperties":false},"IsProject":{"type":"boolean"},"Source":{"type":"string"},"PrimaryTaxIdentifier":{"type":"string"},"GSTRegistrationType":{"type":"string"},"PrintOnCheckName":{"type":"string"},"BillAddr":{"type":"object","properties":{"Id":{"type":"string"},"PostalCode":{"type":"string"},"City":{"type":"string"},"Country":{"type":"string"},"Line5":{"type":"string"},"Line4":{"type":"string"},"Line3":{"type":"string"},"Line2":{"type":"string"},"Line1":{"type":"string"},"Lat":{"type":"string"},"Long":{"type":"string"},"CountrySubDivisionCode":{"type":"string"}},"required":["Id"],"additionalProperties":false},"FullyQualifiedName":{"type":"string"},"Level":{"type":"integer"},"TaxExemptionReasonId":{"type":"integer"},"domain":{"type":"string"},"sparse":{"type":"boolean"}},"required":["Id"],"additionalProperties":false}',
               instance := metadata
             )
           )
      );
    meta.insert_table_meta('qbo_customer', 'general');

    drop table if exists qbo_customer_type;
      create table qbo_customer_type (
         id uuid primary key default uuid_generate_v4(),
         table_data jsonp not null,
           check (
             json_matches_schema (
               schema := '{"title":"CustomerType","description":"https://developer.intuit.com/app/developer/qbo/docs/api/accounting/all-entities/customertype","type":"object","properties":{"Id":{"type":"string"},"SyncToken":{"type":"string"},"Name":{"type":"string"},"Active":{"type":"boolean"},"MetaData":{"type":"object","properties":{"CreateTime":{"type":"string"},"LastUpdatedTime":{"type":"string"}},"additionalProperties":false},"domain":{"type":"string"},"sparse":{"type":"boolean"}},"required":["Id"],"additionalProperties":false}',
               instance := metadata
             )
           )
      );
    meta.insert_table_meta('qbo_customer_type', 'general');

    drop table if exists qbo_employee;
      create table qbo_employee (
         id uuid primary key default uuid_generate_v4(),
         table_data jsonp not null,
           check (
             json_matches_schema (
               schema := '{"title":"Employee","description":"https://developer.intuit.com/app/developer/qbo/docs/api/accounting/all-entities/employee","type":"object","properties":{"Id":{"type":"string"},"SyncToken":{"type":"string"},"PrimaryAddr":{"type":"object","properties":{"Id":{"type":"string"},"PostalCode":{"type":"string"},"City":{"type":"string"},"Country":{"type":"string"},"Line5":{"type":"string"},"Line4":{"type":"string"},"Line3":{"type":"string"},"Line2":{"type":"string"},"Line1":{"type":"string"},"Lat":{"type":"string"},"Long":{"type":"string"},"CountrySubDivisionCode":{"type":"string"}},"required":["Id"],"additionalProperties":false},"PrimaryEmailAddr":{"type":"object","properties":{"Address":{"type":"string"}},"additionalProperties":false},"DisplayName":{"type":"string"},"Title":{"type":"string"},"BillableTime":{"type":"boolean"},"GivenName":{"type":"string"},"BirthDate":{"type":"object","properties":{"date":{"type":"string"}},"additionalProperties":false},"MiddleName":{"type":"string"},"SSN":{"type":"string"},"PrimaryPhone":{"type":"object","properties":{"FreeFormNumber":{"type":"string"}},"additionalProperties":false},"Active":{"type":"boolean"},"ReleasedDate":{"type":"object","properties":{"date":{"type":"string"}},"additionalProperties":false},"MetaData":{"type":"object","properties":{"CreateTime":{"type":"string"},"LastUpdatedTime":{"type":"string"}},"additionalProperties":false},"CostRate":{"type":"number"},"Mobile":{"type":"object","properties":{"FreeFormNumber":{"type":"string"}},"additionalProperties":false},"Gender":{"type":"string"},"HiredDate":{"type":"object","properties":{"date":{"type":"string"}},"additionalProperties":false},"BillRate":{"type":"number"},"Organization":{"type":"boolean"},"Suffix":{"type":"string"},"FamilyName":{"type":"string"},"PrintOnCheckName":{"type":"string"},"EmployeeNumber":{"type":"string"},"domain":{"type":"string"},"sparse":{"type":"boolean"}},"required":["Id"],"additionalProperties":false}',
               instance := metadata
             )
           )
      );
    meta.insert_table_meta('qbo_employee', 'general');

    alter table qbo_customer_info
      enable row level security;

    alter table qbo_customer
      enable row level security;

    alter table qbo_customer_type
      enable row level security;

    alter table qbo_employee
      enable row level security;

--    -- policies for setting permissions for operating on roles
--    execute format(E'
--      drop policy if exists "role";
--      create policy "role" on %I.role for all
--        using (check_can_operate_on_role(schema_path, auth.uid(), TG_OP))
--        with check (check_can_operate_on_role(schema_path, auth.uid(), TG_OP));
--    ', schema_path);
--    execute format(E'
--      drop policy if exists "role_permission";
--      create policy "role_permission" on %I.role_permission for all
--        using (check_can_operate_on_role(schema_path, auth.uid(), TG_OP))
--        with check (check_can_operate_on_role(schema_path, auth.uid(), TG_OP));
--    ', schema_path);
--    execute format(E'
--      drop policy if exists "role";
--      create policy "role" on %I.role for all
--        using (check_can_operate_on_role(schema_path, auth.uid(), TG_OP))
--        with check (check_can_operate_on_role(schema_path, auth.uid(), TG_OP));
--    ', schema_path);
--    execute format(E'
--      drop policy if exists "role_profile_mapping";
--      create policy "role_profile_mapping" on %I.role_profile_mapping for all
--        using (check_can_operate_on_role(schema_path, auth.uid(), TG_OP))
--        with check (check_can_operate_on_role(schema_path, auth.uid(), TG_OP));
--    ', schema_path);
--    execute format(E'
--      drop policy if exists "profile_permission";
--      create policy "profile_permission" on profile_permission for all
--        using (check_can_operate_on_role(schema_path, auth.uid(), TG_OP))
--        with check (check_can_operate_on_role(schema_path, auth.uid(), TG_OP));
--    ', schema_path);
--
--    -- policies which apply role permissions to other tables
--    execute format(E'
--      drop policy if exists "qbo_customer";
--      create policy "qbo_customer" on %I.qbo_customer for all
--       using (check_permissions(auth.uid(), 'qbo_customer', TG_OP, id))
--       with check (check_permissions(auth.uid(), 'qbo_customer', TG_OP, id));
--    ', schema_path);


     -- auto generate policies for tables which have the auto flag
     do $$
       declare
         table_name text;
       begin
         for table_name in (select table_name from tenant_schema_table_info where table_type = 'general') loop
           execute format(E'
             drop policy if exists "%S";
             create policy "%S" on %I.%I for all
              using (check_permissions(auth.uid(), \'%S\', TG_OP, id))
              with check (check_permissions(auth.uid(), \'%S\', TG_OP, id));
           ', table_name, table_name, schema_path, table_name, table_name, table_name);
         end loop;
       end; $$

    -- auto generate policies for tables which have the auto flag
    do $$
      declare
        table_name text;
      begin
        for table_name in (select table_name from tenant_schema_table_info where table_type = 'role') loop
          execute format(E'
            drop policy if exists "%S";
            create policy "%S" on %I.%I for all
              using (check_can_operate_on_role(%S, auth.uid(), TG_OP))
              with check (check_can_operate_on_role(%S, auth.uid(), TG_OP));
          ', table_name, table_name, schema_path, table_name, schema_path, schema_path);
        end loop;
      end; $$
  end; $$ language plpgsql;

















