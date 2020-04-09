/* We sometimes have the situation
   that we need to test functions and
   don't exactly know all the details of its
   internals.

   This is the setup part
 */
create table deathstar_rooms (
  id integer generated by default on null as identity primary key,
  name varchar2(200) not null,
  code varchar2(200) not null unique
);

insert into deathstar_rooms ( name, code ) values ( 'Engine Room 1', 'ENG1' );
insert into deathstar_rooms ( name, code ) values ( 'Vaders Chamber', 'VADER' );
insert into deathstar_rooms ( name, code ) values ( 'Bridge', 'BRIDGE' );
insert into deathstar_rooms ( name, code ) values ( 'Prison 1', 'PRISON1' );

create table room_inventory (
  id integer generated by default on null as identity primary key,
  room_id integer not null,
  item varchar2(400) not null,
  nr_in_room integer,
  constraint room_inventory_fk_room foreign key ( room_id )
    references deathstar_rooms (id)
);

/* We add some nasty trigger mechanic to the inventory
   table. Dont do this in production, there are far better
   ways to get to the same result
 */
create or replace trigger trg_set_nr_in_room before insert or update on room_inventory
  for each row
begin
  if ( inserting or (updating and :old.room_id <> :new.room_id)) then
    declare
      l_max_nr integer;
    begin
      select max(nr_in_room) into l_max_nr
        from room_inventory
        where room_id = :new.room_id;
      :new.nr_in_room := nvl(l_max_nr,0)+1;
    end;
  end if;
end;
/

/* We have a room_util-package that we only know
   from the outside
 */
create or replace package room_util as
  subtype varchar2_nn is varchar2 not null;
  procedure add_item(
    i_item_name in varchar2_nn,
    i_room_code in varchar2_nn);
end;
/

create or replace package body room_util as
  procedure add_item(
    i_item_name in varchar2_nn,
    i_room_code in varchar2_nn)
  as
    begin
      insert into room_inventory ( room_id, item )
        values ( (select id from deathstar_rooms where code = i_room_code), i_item_name );
    end;
end;
/

/*
 Now lets explore the ADD_ITEM functionality
 through tests
 */

create or replace package ut_room_inventory as
  -- %suite(Room Inventory)

  -- %beforeall
  procedure setup_test_room;

  -- %test(Add a new item to the inventory of a room)
  procedure add_item;
end;
/

create or replace package body ut_room_inventory as
  /* Just add a test-room we can rely on */
  procedure setup_test_room
  as
    begin
      insert into deathstar_rooms ( id, name, code )
        values ( -1, 'Secret Test chamber', 'TEST');
    end;

  procedure add_item
  as
    begin
      -- Lets just add some things and evaluate what we
      -- should even test for
      room_util.add_item('Light saber (red)', 'TEST');
      room_util.add_item('Light saber (blue)', 'TEST');
      room_util.add_item('Light saber (green)', 'TEST');
    end;
end;
/

/* Now call ut.run with the a_force_manual_rollback parameter */
begin
  ut.run(a_path=>'ut_room_inventory', a_force_manual_rollback=>true);
end;
/

/* You can now find out what to test for */
select * from deathstar_rooms;
select * from room_inventory where room_id < 0;

/* Important! Dont forget to rollback */
rollback;

select * from room_inventory;

/* Now we can implement our actual test */
create or replace package body ut_room_inventory as
  /* Just add a test-room we can rely on */
  procedure setup_test_room
  as
    begin
      insert into deathstar_rooms ( id, name, code )
        values ( -1, 'Secret Test chamber', 'TEST');
    end;

  procedure add_item
  as
    c_actual sys_refcursor;
    c_expect sys_refcursor;
    begin
      room_util.add_item('Light saber (red)', 'TEST');
      room_util.add_item('Light saber (blue)', 'TEST');
      room_util.add_item('Light saber (green)', 'TEST');

      open c_actual for
        select item, nr_in_room from room_inventory where room_id = -1
        order by id;
      open c_expect for
        select 'Light saber (red)' item, 1 nr_in_room from dual union all
        select 'Light saber (blue)'    , 2            from dual union all
        select 'Light saber (green)'   , 3            from dual;

      ut.expect(c_actual).to_equal(c_expect);
    end;
end;
/

/* We now have a test for the functionality
   and can start to refactor
 */
call ut.run('ut_room_inventory');