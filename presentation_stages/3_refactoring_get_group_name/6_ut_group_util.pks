create or replace package ut_group_util as

  -- %suite(Group-Util)
  -- %suitepath(army.groups)

  -- %test(get_group_name returns name of group type and number)
  procedure get_group_name_normal;

  -- %test(get_group_name honor name if one is available)
  procedure get_group_name_honor;
end;
/