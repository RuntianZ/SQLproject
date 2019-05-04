-- Constraint task 2: Employees

create database emp
go

use emp
go

create schema pg
go

-- Create table
create table pg.emp
(
    eid    int not null,
    ename  varchar(20),
    age    int,
    salary int not null,
    did    int
        primary key (eid)
)
go

create table pg.dept
(
    did       int not null,
    budget    int not null,
    managerid int,
    primary key (did),
    foreign key (managerid) references pg.emp (eid)
)
go

alter table pg.emp
    add foreign key (did) references pg.dept (did)
go

-- Returns 0 if the manager's salary is the highest
create function pg.fn_mgr_salary()
    returns int
as
begin
    return (
        select count(*)
        from pg.dept D
        where exists(
                      select *
                      from pg.emp E1,
                           pg.emp E2
                      where E1.did = D.did
                        and E2.eid = D.managerid
                        and E1.salary > E2.salary
                  )
    )
end
go

-- Add constraints
alter table pg.emp
    add constraint CK_emp_mgr_salary check (pg.fn_mgr_salary() = 0)
go

alter table pg.dept
    add constraint CK_dept_mgr_salary check (pg.fn_mgr_salary() = 0)
go

-- Create trigger
create trigger TRIG_budget_update
    on pg.emp
    after insert, delete, update
    as
begin
    update pg.dept
    set budget = budget - (
        select coalesce(sum(salary), 0)
        from deleted del
        where del.did = pg.dept.did
    );

    update pg.dept
    set budget = budget + (
        select coalesce(sum(salary), 0)
        from inserted ins
        where ins.did = pg.dept.did
    )
end
go