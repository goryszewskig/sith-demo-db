/* Setup */
create table force_powers (
  id integer generated by default as identity not null primary key,
  structure varchar2(50) not null,
  name varchar2(100) not null,
  constraint force_powers_uq_struct unique ( structure )
);

insert into force_powers (structure, name) values ( '1', 'Universal' );
insert into force_powers (structure, name) values ( '1.1', 'Telekinesis' );
insert into force_powers (structure, name) values ( '1.1.1', 'Force Push' );
insert into force_powers (structure, name) values ( '1.1.2', 'Force Pull' );
insert into force_powers (structure, name) values ( '1.1.3', 'Force Jump' );
insert into force_powers (structure, name) values ( '2', 'Light' );
insert into force_powers (structure, name) values ( '2.1', 'Mind Trick' );
insert into force_powers (structure, name) values ( '2.1.1', 'Force Persuation' );
insert into force_powers (structure, name) values ( '3', 'Dark' );
insert into force_powers (structure, name) values ( '3.1', 'Force wound' );
insert into force_powers (structure, name) values ( '3.1.1', 'Force grip' );
insert into force_powers (structure, name) values ( '3.1.2', 'Force choke' );

create or replace type t_numeric_structure force as object
(
  c_level1 number(3,0),
  c_level2 number(3,0),
  c_level3 number(3,0),

  constructor function t_numeric_structure(
    i_struct varchar2 )
    return self as result,
  member function p$_position_for_level(
    i_string varchar2,
    i_level positiven ) return pls_integer,
  member function level1 return pls_integer,
  member function level2 return pls_integer,
  member function level3 return pls_integer,
  member function structure return varchar2,
  member function sort return varchar2,
  member function depth return pls_integer,
  member function parent return t_numeric_structure
);
/

create or replace type body t_numeric_structure as

  constructor function t_numeric_structure(
    i_struct varchar2 )
    return self as result
  as
    begin
      self.c_level1 := p$_position_for_level(i_struct, 1);
      self.c_level2 := p$_position_for_level(i_struct, 2);
      self.c_level3 := p$_position_for_level(i_struct, 3);
      return;
    end;

  member function p$_position_for_level(
    i_string in varchar2,
    i_level in positiven ) return pls_integer
  as
    begin
      return
        nvl(to_number(
          regexp_substr(i_string, '[0-9]+', 1, i_level)
        ),0);
    end;

  member function level1 return pls_integer
  as
    begin
      return c_level1;
    end;

  member function level2 return pls_integer
  as
    begin
      return c_level2;
    end;

  member function level3 return pls_integer
  as
    begin
      return c_level3;
    end;

  member function structure return varchar2
  as
    l_result varchar2(50);
    begin
      if ( c_level1 > 0 ) then
        l_result := to_char(c_level1);
      end if;
      if ( c_level2 > 0 ) then
        l_result := l_result || '.' || to_char(c_level2);
      end if;
      if ( c_level3 > 0 ) then
        l_result := l_result || '.' || to_char(c_level3);
      end if;
      return l_result;
    end;

  member function sort return varchar2
  as
    begin
      return lpad(c_level1, 3, '0')
        || lpad(c_level2, 3, '0')
        || lpad(c_level3, 3, '0');
    end;

  member function depth return pls_integer
  as
    begin
      if c_level3 > 0 then
        return 3;
      elsif c_level2 > 0 then
        return 2;
      elsif c_level1 > 0 then
        return 1;
      else
        return 0;
      end if;
    end;

  member function parent return t_numeric_structure
  as
    begin
      if ( c_level3 > 0 ) then
        return new t_numeric_structure(
          to_char(c_level1)||'.'||to_char(c_level2));
      elsif ( c_level2 > 0 ) then
        return new t_numeric_structure(
          to_char(c_level1));
      else
        return null;
      end if;
    end;
end;
/


select * from force_powers;

-- First add a new column to the table
alter table force_powers
  add struct t_numeric_structure;

-- Then fill the new column
update force_powers
  set struct = t_numeric_structure(structure);

-- We can now easily select from the type
select
  p.id,
  p.name,
  p.struct.structure() structure
  from force_powers p;

-- By the way: It doesnt work to select
-- without a table alias
select
  p.id,
  p.name,
  struct.structure() structure
  from force_powers p;

-- Now let's make the new column unique

-- It doesnt work to add a unique constraint on the type
alter table force_powers
  add constraint force_powers_uq_struct_new unique ( struct );

-- Neither can it be done via a function
alter table force_powers
  add constraint force_powers_uq_struct_new unique ( struct.structure() );

-- And also not via a unique function-based index
-- because the function is not deterministic
create unique index idx_force_powers_struct on
  force_powers ( struct.structure() );

-- But its totally possible to have a unique constraint
-- on the PROPERTIES of the type
alter table force_powers
  add constraint force_powers_uq_struct_new unique
    ( struct.c_level1, struct.c_level2, struct.c_level3 );

-- Now lets get rid of the old structure column
alter table force_powers
  drop column structure;

-- And Assure the unique index works
insert into force_powers ( name, struct )
select 'some name', t_numeric_structure('4.0.0')
from dual connect by level <= 10;

-- Also via update
update force_powers p
  set struct = t_numeric_structure('4.0.0')
  where p.struct.structure() like '3%';

-- We still can insert a new row
insert into force_powers ( name, struct )
  values ( 'Force healing', t_numeric_structure('2.2'));

-- And update
update force_powers p
  set struct = t_numeric_structure('3.1.3')
  where p.struct.structure() = '3.1.2';

select
  base.id,
  base.struct.structure() structure,
  base.name,
  base.struct.level1() level1,
  base.struct.level2() level3,
  base.struct.level3() level3,
  base.struct.depth() depth,
  base.struct.sort() sort,
  (select id
     from force_powers parent
     where parent.struct.structure() =
           base.struct.parent().structure()
  ) parent_id
  from
    force_powers base;

-- So ... back to that function-based index problem
create unique index idx_force_powers_uq_struct on
  force_powers ( struct.structure() );

-- Function is not deterministic - so lets change that.

create or replace type t_numeric_structure force as object
(
  c_level1 number(3,0),
  c_level2 number(3,0),
  c_level3 number(3,0),

  constructor function t_numeric_structure(
    i_struct varchar2 )
    return self as result,
  member function p$_position_for_level(
    i_string varchar2,
    i_level positiven ) return pls_integer,
  member function level1 return pls_integer,
  member function level2 return pls_integer,
  member function level3 return pls_integer,
  member function structure return varchar2
    deterministic,
  member function sort return varchar2,
  member function depth return pls_integer,
  member function parent return t_numeric_structure2
);
/

-- We cant do this because our type is used in a table
-- Therefore we have to remove it from the table,
-- change it and then re-add it:

-- First store the value in a new column
alter table force_powers
  add strucutre_backup varchar2(12);

update force_powers p
  set strucutre_backup = p.struct.structure();

-- Now remove the type-column and change the type
alter table force_powers
  drop column struct;

create or replace type t_numeric_structure force as object
(
  c_level1 number(3,0),
  c_level2 number(3,0),
  c_level3 number(3,0),

  constructor function t_numeric_structure(
    i_struct varchar2 )
    return self as result,
  member function p$_position_for_level(
    i_string varchar2,
    i_level positiven ) return pls_integer,
  member function level1 return pls_integer,
  member function level2 return pls_integer,
  member function level3 return pls_integer,
  member function structure return varchar2
    deterministic,
  member function sort return varchar2,
  member function depth return pls_integer,
  member function parent return t_numeric_structure
);
/

create or replace type body t_numeric_structure as

  constructor function t_numeric_structure(
    i_struct varchar2 )
    return self as result
  as
    begin
      self.c_level1 := p$_position_for_level(i_struct, 1);
      self.c_level2 := p$_position_for_level(i_struct, 2);
      self.c_level3 := p$_position_for_level(i_struct, 3);
      return;
    end;

  member function p$_position_for_level(
    i_string in varchar2,
    i_level in positiven ) return pls_integer
  as
    begin
      return
        nvl(to_number(
          regexp_substr(i_string, '[0-9]+', 1, i_level)
        ),0);
    end;

  member function level1 return pls_integer
  as
    begin
      return c_level1;
    end;

  member function level2 return pls_integer
  as
    begin
      return c_level2;
    end;

  member function level3 return pls_integer
  as
    begin
      return c_level3;
    end;

  member function structure return varchar2
    deterministic
  as
    l_result varchar2(50);
    begin
      if ( c_level1 > 0 ) then
        l_result := to_char(c_level1);
      end if;
      if ( c_level2 > 0 ) then
        l_result := l_result || '.' || to_char(c_level2);
      end if;
      if ( c_level3 > 0 ) then
        l_result := l_result || '.' || to_char(c_level3);
      end if;
      return l_result;
    end;

  member function sort return varchar2
  as
    begin
      return lpad(c_level1, 3, '0')
        || lpad(c_level2, 3, '0')
        || lpad(c_level3, 3, '0');
    end;

  member function depth return pls_integer
  as
    begin
      if c_level3 > 0 then
        return 3;
      elsif c_level2 > 0 then
        return 2;
      elsif c_level1 > 0 then
        return 1;
      else
        return 0;
      end if;
    end;

  member function parent return t_numeric_structure
  as
    begin
      if ( c_level3 > 0 ) then
        return new t_numeric_structure(
          to_char(c_level1)||'.'||to_char(c_level2));
      elsif ( c_level2 > 0 ) then
        return new t_numeric_structure(
          to_char(c_level1));
      else
        return null;
      end if;
    end;
end;
/

-- Now Re-add the type
alter table force_powers
  add struct t_numeric_structure;

update force_powers p
  set struct = t_numeric_structure(strucutre_backup);

-- Add the unique index
-- We are using substr here to tell the index that the
-- resulting string will be a varchar2(12)
-- Otherwise it will assume varchar2(4000) for we can not
-- hint the length of a varchar2 returned by a function
create unique index idx_force_powers_uq_struct on
  force_powers ( substr(struct.structure(),1,12) );


-- Lets again prove the index works
insert into force_powers ( name, struct )
select 'some name', t_numeric_structure('4.0.0')
from dual connect by level <= 10;

update force_powers p
  set struct = t_numeric_structure('4.0.0')
  where p.struct.structure() like '3%';

-- The index is also used when querying
select
  p.id,
  p.name,
  p.struct.structure() structure
  from force_powers p
  where p.struct.structure() = '1.1.1';