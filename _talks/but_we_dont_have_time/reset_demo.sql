drop table deathstar_rooms;
drop table deathstar_sections;

create table deathstar_sections (
  id integer not null primary key,
  label varchar2(200)
);

create table deathstar_rooms (
  id integer generated by default on null as identity primary key,
  name varchar2(200) not null,
  code varchar2(200) not null unique,
  section_id integer not null,
  nr_in_section integer,
  constraint deathstar_rooms_fk_section foreign key (section_id)
    references deathstar_sections( id )
);

insert into deathstar_sections(id, label) values ( 1, 'Section 1');
insert into deathstar_sections(id, label) values ( 2, 'Bridge');

insert into deathstar_rooms ( name, code, section_id, nr_in_section ) values ( 'Engine Room 1', 'ENG1', 1, 1 );
insert into deathstar_rooms ( name, code, section_id, nr_in_section ) values ( 'Vaders Chamber', 'VADER', 1, 2 );
insert into deathstar_rooms ( name, code, section_id, nr_in_section ) values ( 'Bridge', 'BRIDGE', 2, 1 );
insert into deathstar_rooms ( name, code, section_id, nr_in_section ) values ( 'Prison 1', 'PRISON1', 1, 3 );

commit;

create or replace package deathstar_room_manager as
  subtype varchar2_nn is varchar2 not null;

  /** Adds a new room to a section
   */
  procedure add_room(
    i_name varchar2_nn,
    i_section_id simple_integer,
    i_code varchar2 default null );
end;
/

create or replace package body deathstar_room_manager as
  procedure add_room(
    i_name varchar2_nn,
    i_section_id simple_integer,
    i_code varchar2 default null )
  as
    l_max_nr_in_section integer;
    l_code varchar2(20) := i_code;
    l_code_max_nr integer;
    begin
      select nvl(max(nr_in_section),0) into l_max_nr_in_section
        from deathstar_rooms
        where section_id = i_section_id;

      if ( i_code is null ) then
        l_code := upper(replace(substr(i_name, 1, 6), ' ', '_'));
        select
          nvl(max(regexp_substr(substr(code, 7), '[0-9]+', 1, 1)),0)
            into l_code_max_nr
          from deathstar_rooms
          where
            substr(code, 1, 6) = l_code
            and regexp_like(substr(code, 7), '^[0-9]+$');

        l_code := l_code || to_char(l_code_max_nr+1);
      end if;

      insert into deathstar_rooms ( name, code, section_id, nr_in_section )
        values ( i_name, l_code, i_section_id, l_max_nr_in_section+1);
    end;
end;
/


create or replace package deathstar_room_view_generator as

  /** Creates a view that only allows access on several rooms
   */
  procedure create_view(
    i_view_name varchar2,
    i_room_ids sys.odcinumberlist
  );

end;
/

create or replace package body deathstar_room_view_generator as

  procedure create_view(
    i_view_name varchar2,
    i_room_ids sys.odcinumberlist
  )
  as
    l_room_ids_str varchar2(4000);
    l_stmt varchar2(4000);
    begin
      if ( i_room_ids.count <= 0 ) then
        raise_application_error(-20000, 'No rooms given');
      end if;

      select listagg(column_value, ',') within group (order by rownum)
        into l_room_ids_str
        from table(i_room_ids)
        where rownum <= 1;

      l_stmt := 'create view ' || dbms_assert.SIMPLE_SQL_NAME(i_view_name) || ' as
      select
        rooms.id,
        rooms.name,
        rooms.code,
        sections.id section_id,
        sections.label section_label
      from
        deathstar_rooms rooms
        inner join deathstar_sections sections
          on rooms.section_id = sections.id
      where rooms.id in (' || l_room_ids_str || ')';

      execute immediate l_stmt;
    end;
end;
/

begin
  for rec in (select object_name
                from table (ut_runner.get_suites_info())
                where item_type = 'UT_SUITE'
                 ) loop
    execute immediate 'drop package "' || rec.object_name || '"';
    dbms_output.put_line(rec.object_name || ' dropped.');
  end loop;
end;
/
;

