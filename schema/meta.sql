-- Enable access to case-insensitive text
create extension if not exists citext;
create extension if not exists "uuid-ossp";

-- [largely from this file](https://github.com/jensen/vote-now/blob/main/src/services/schema/tables.sql)
-- Users
create schema if not exists "meta";
set search_path to meta;

-- TABLE DEFINITIONS ---------------------------------------------------------------------

-- table which stores meta-data about our tenants, including the name of the schema_path
--  used to access their schema
drop table if exists tenant;
  create table tenant (
      id uuid primary key default uuid_generate_v4(),
      schema_path text not null,
      owner_profile_id uuid
  );

-- table which stores a mapping between tenant meta-data and user profiles. if a
--  record in this exists, then that user is considered to be a part of that tenant
drop table if exists tenant_profile_mapping;
  create table tenant_profile_mapping (
    id uuid primary key default uuid_generate_v4(),
    profile_id uuid,
    tenant_id uuid
  );

-- table which stores public profile information about the user, and is generated
--  automatically from auth.users
drop table if exists profile;
  create table profile (
    id uuid references auth.users primary key,
    name text,
    avatar text
  );

-- table which stores private profile information
drop table if exists profile_private;
  create table profile_private (
    id uuid references profile(id) primary key,
    email citext,
    phone text,
    admin boolean default false not null
  );

create type tenant_schema_table_type AS ENUM ('auto', 'role');

-- table which stores meta information about tables in tenant schemas, like
--  whether or not they should be included in the auto generation of
--  policies (tables which dont govern permissions and are visible to our customers)
drop table if exists tenant_schema_table_info;
  create table tenant_schema_table_info (
    id uuid primary key default uuid_generate_v4(),
    table_name text not null unique,
    table_type tenant_schema_table_type not null
  );

-- a store of json schemas in json-schema format that are being used for validating
--  json strings stored in columns on tables in tenant schemas
drop table if exists json_schema_store;
  create table json_schema_store (
     id uuid primary key default uuid_generate_v4(),
     table_name text not null, -- TODO: write function which checks if this already exists or not before inserting
     table_column text not null,
     json_schema jsonp not null
  );

-- TABLE ALTERATIONS ---------------------------------------------------------------------
alter table tenant
  add constraint fk_owner_profile_id foreign key (owner_profile_id) references profile(id),
  enable row level security;

alter table tenant_profile_mapping
  add constraint fk_profile_id foreign key (profile_id) references profile(id),
  add constraint fk_tenant_id foreign key (tenant_id) references tenant(id),
  enable row level security;

alter table profile_private
  enable row level security;

-- FUNCTIONS ---------------------------------------------------------------------
drop function if exists has_tenant_schema_access;
  create or replace function has_tenant_schema_access(schema_name text) returns boolean AS $$
  begin
    select exists (
      select 1 from tenant_profile_mapping
      join tenants on tenant_profile_mapping.tenant_id = tenants.id
      where tenant_profile_mapping.user_id = auth.uid()
      and tenants.schema_name = schema_name
    );
  end;
  $$ language plpgsql security definer set search_path = meta;

drop function if exists get_is_admin();
  create or replace function get_is_admin() returns boolean as $$
    select profile_private.admin
    from profile_private
    where profile_private.id = auth.uid()
  $$ language sql security definer set search_path = meta;


/** NOTE: when you end a function with "$$ language plpgsql security definer set search_path = public", it means that within the context
    of the function's execution, the search_path will be set to public. */

drop function if exists handle_new_user();
  create function handle_new_user() returns trigger as $$
  begin
    insert into profile (id, name, avatar)
    values (
      new.id,
      new.raw_user_meta_data::json->>'full_name',
      new.raw_user_meta_data::json->>'avatar_url'
    );

    insert into profile_private (id, email, phone)
    values (
      new.id,
      new.email,
      new.phone
    );
    return new;
  end;
  $$ language plpgsql security definer set search_path = meta;

drop function if exists handle_update_user();
  create or replace function handle_update_user() returns trigger as $$
  begin
    update profile
    set name = new.raw_user_meta_data::json->>'full_name',
        avatar = new.raw_user_meta_data::json->>'avatar_url'
    where id = NEW.id;
    update profile_private
    set email = new.email,
        phone = new.phone
    where id = new.id;
    return new;
  end;
  $$ language plpgsql security definer set search_path = meta;

-- POLICIES ---------------------------------------------------------------------
drop policy if exists "(all) tenant - Only triggers should have access to this table." on tenant;
  create policy "(all) tenant - Only triggers should have access to this table." on tenant for all to supabase_admin;

drop policy if exists "(update) profile - Profiles are only updatable by owner or by admin" on profile;
  create policy "(update) profile - Profiles are only updatable by owner or by admin" on profile for update
    using (true)
    with check (
      auth.role() = 'authenticated'
      and (get_is_admin() or auth.uid() = id)
    );

/** NOTE: The USING expression determines which records the UPDATE command will see to operate against, while
    the WITH CHECK expression defines which modified rows are allowed to be stored back into the relation.
    In other words, only the records which match the condition in USING will be members of the policy,
    and, when doing a write, only the records which match the condition in WITH MATCH will be updated by the
    query. */

drop policy if exists "(select) profile - Profiles are only viewable if authenticated" on profile;
  create policy "(select) profile - Profiles are only viewable if authenticated" on profile for select
   using (auth.role() = 'authenticated');

drop policy if exists "(select) profile_private - Private profile are only visible by the user who owns it" on profile_private;
  create policy "(select) profile_private - Private profile are only visible by the user who owns it" on profile_private for select
    using (
      get_is_admin()
      or auth.uid() = id
    );

drop policy if exists "(update) profile_private - The admin field is only updatable by other admins" on profile_private;
  create policy "(update) profile_private - The admin field is only updatable by other admins" on profile_private for update
    using (true)
    with check (get_is_admin());

-- TRIGGERS ---------------------------------------------------------------------
drop trigger if exists on_auth_user_created on auth.users;
  create trigger on_auth_user_created
    after insert on auth.users
    for each row execute procedure handle_new_user();

drop trigger if exists on_auth_user_updated on auth.users;
  create trigger on_auth_user_updated
    after update on auth.users
    for each row execute procedure handle_update_user();
