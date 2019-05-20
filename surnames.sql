-- Task 1: Surnames

-- Create table
create table dbo.surnames(
    parent varchar(8),
    child varchar(8)
)

-- surnames.txt needs preprocessing
bulk insert dbo.surnames
    from 'surnames.txt'
    with (
    fieldterminator = ',',
    rowterminator = '\n'
    )
go

-- Compute the levels of all nodes
create table dbo.level(
    surname varchar(8),
    level int,
    primary key (surname)
)
go

insert into dbo.level
select distinct surname, null
from (
     select parent as surname
     from dbo.surnames
     union
     select child as surname
     from dbo.surnames
         ) T
go

-- Root nodes
update dbo.level
set level = 0
where not exists(
    select *
    from dbo.surnames
    where child = surname
      and parent != surname
    )
go

-- Iteratively compute levels
declare @lvl as int = 1;
declare @a as int;
while 1 = 1
begin
    set @a = (select count(*) from dbo.level where level is null);
    if @a = 0 break;
    update dbo.level
    set level = @lvl
    where level is null
    and exists(
        select *
        from dbo.level L, dbo.surnames S
        where L.surname = S.parent
          and L.level is not null
          and dbo.level.surname = S.child
        )
    set @lvl = @lvl + 1;
end
go

-- Create functions
create function dbo.get_parent(@sn varchar(8))
returns @parents table (
    parent varchar(8),
    level int
              )
as
begin
    insert into @parents
    select *
    from dbo.level
    where exists(
        select *
        from dbo.surnames
        where parent = dbo.level.surname
          and child = @sn
              );
    return;
end
go


create function dbo.get_child(@sn varchar(8))
returns @parents table (
    parent varchar(8),
    level int
              )
as
begin
    insert into @parents
    select *
    from dbo.level
    where exists(
        select *
        from dbo.surnames
        where child = dbo.level.surname
          and parent = @sn
              );
    return;
end
go

-- Test
select *
from
dbo.get_child('颛顼')
