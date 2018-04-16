create or replace package ut_groups as
  -- %suite(Groups View)

  -- %test
  procedure select_fire_unit;

  -- %test(Fail update when nr in group is not unique)
  -- %throws(-00001)
  procedure fail_on_duplicate_groupnr;

  -- %beforeall
  procedure setup;
end;
/