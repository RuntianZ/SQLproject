-- Constraint task 1: ID card

create database idcard;
go

use idcard;
go

create schema card;
go

-- Returns 0 only if an id card is valid
create function card.check_id(@id char(18))
    returns int
as
begin
    declare
        @ids char(18) = '68947310526894731';
    declare
        @idc char(11) ='10X98765432';
    declare
        @i int, @c1 char, @c2 char, @j1 int, @j2 int;
    declare
        @sum int = 0;
    set @i = 0;
    while @i < 17
    begin
        set @i = @i + 1;
        set @c1 = substring(@id, @i, 1);
        set @c2 = substring(@ids, @i, 1);
        set @j1 = ascii(@c1) - 48;
        set @j2 = ascii(@c2) - 47;
        set @sum = @sum + @j1 * @j2;
    end
    set @c1 = substring(@id, 18, 1);
    set @c2 = substring(@idc, @sum % 11 + 1, 1);
    return ascii(@c1) - ascii(@c2);
end
go

-- Create table
create table card.people
(
    id   char(18)    not null,
    name varchar(20) not null,
    primary key (id),
    check(card.check_id(id) = 0)
)
go
