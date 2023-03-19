-- All integrations + available settings
create table intg (
    id varchar not null,
    display_name varchar not null,
    display_order smallint not null default 1,
    is_enabled bool not null default false,
    primary key (id)
);

create table intg_settings (
    id serial not null,
    intg_id varchar references intg (id),
    setting_name varchar not null,
    display_name varchar not null,
    display_order smallint not null default 1,
    element_type varchar not null,
    element_config jsonb not null,
    element_default varchar not null,
    primary key (id)
);

create or replace function get_ui_config() returns jsonb as
$$
with int_sets as (select intg_id,
                      jsonb_build_object(
                              'setting_name', setting_name,
                              'display_name', display_name,
                              'display_order', display_order,
                              'element_type', element_type,
                              'element_config', element_config,
                              'element_default', element_default
                          ) as st
                  from integrations.intg_settings),
    intgs as (select jsonb_build_object(
            'id', ig.id,
            'display_name', ig.display_name,
            'display_order', ig.display_order,
            'is_enabled', ig.is_enabled,
            'settings', coalesce(
                            jsonb_agg(igs.st) filter (where igs.st is not null),
                            '[]')
        ) intg_json
              from integrations.intg ig
                       left join int_sets igs on ig.id = igs.intg_id
              group by ig.id)
select jsonb_build_object(
        'integrations',
        jsonb_agg(i.intg_json)) as config
from intgs i;
$$ language sql;

-- Customer integrations & settings
create table cust_intg (
    id serial not null,
    cust_id int not null,
    intg_id varchar not null references intg (id),
    primary key (id)
);
create index cust_intg_intg on cust_intg (cust_id, intg_id);

create table cust_intg_settings (
    cust_intg_id int not null references cust_intg (id),
    setting_name varchar not null,
    setting_value jsonb not null,
    primary key (cust_intg_id, setting_name)
);

create or replace function get_cust_intg_settings(customerId int,
                                                  integration varchar,
                                                  integrationId int)
    returns jsonb
    returns null on null input
as
$$
select jsonb_build_object('settings', jsonb_object_agg(
        cis.setting_name,
        cis.setting_value))
from integrations.cust_intg ci
         left join integrations.cust_intg_settings cis
                   on ci.id = cis.cust_intg_id
where ci.cust_id = customerId
  and ci.intg_id = integration
  and ci.id = integrationId
group by ci.cust_id
$$ language sql;
