-- Trigger tasks 1 and 2: stocks

create database stocks;
go

use stocks;
go

create schema stk;
go

-- Create tables
create table stk.my_stock
(
    stock_id  int not null,
    volume    int,
    avg_price smallmoney,
    profit    smallmoney,
    primary key (stock_id)
)
go

create table stk.trans
(
    trans_id    int not null,
    stock_id    int,
    date        int,
    price       smallmoney,
    amount      int,
    sell_or_buy char,
    primary key (trans_id),
    check (sell_or_buy in ('S', 'B'))
)
go

create trigger TRIG_CK_volume
    on stk.trans
    instead of insert
    as
begin
    select *
    into #tmp1
    from (
             select stock_id, date, -amount as amount
             from inserted
             where sell_or_buy = 'B'
             union
             select stock_id, date, amount
             from inserted
             where sell_or_buy = 'S') T

    declare
        @a as int = isnull((
            select count(*)
            from ((
                      select A.stock_id, sum(B.amount) amount_sum
                      from #tmp1 A,
                           #tmp1 B
                      where B.date <= A.date
                      group by A.stock_id
                  ) S
                     left outer join stk.my_stock on S.stock_id = stk.my_stock.stock_id)
            where (volume is null and amount_sum > 0)
               or amount_sum > volume), 0);

    if @a = 0
        insert into stk.trans
        select *
        from inserted
    else
        raiserror('Insert failed: Sell more than bought.', 16, 1);

    drop table #tmp1
end


-- Create trigger: update my_stock after records insterted into trans
create trigger TRIG_trans_update
    on stk.trans
    after insert
    as
begin
    insert into stk.my_stock
    select distinct ins.stock_id, 0, 0, 0
    from inserted ins
    where not exists(
            select *
            from stk.my_stock S
            where S.stock_id = ins.stock_id
        )

    update stk.my_stock
    set avg_price = avg_price * volume +
                    (
                        select isnull(sum(amount * price), 0)
                        from inserted ins
                        where ins.sell_or_buy = 'B'
                          and ins.stock_id = stk.my_stock.stock_id
                    ) -
                    (
                        select isnull(sum(amount * price), 0)
                        from inserted ins
                        where ins.sell_or_buy = 'S'
                          and ins.stock_id = stk.my_stock.stock_id
                    )

    update stk.my_stock
    set volume = volume +
                 (
                     select isnull(sum(amount), 0)
                     from inserted ins
                     where ins.sell_or_buy = 'B'
                       and ins.stock_id = stk.my_stock.stock_id
                 ) -
                 (
                     select isnull(sum(amount), 0)
                     from inserted ins
                     where ins.sell_or_buy = 'S'
                       and ins.stock_id = stk.my_stock.stock_id
                 )

    update stk.my_stock
    set avg_price = avg_price / volume
    where volume > 0

    delete from stk.my_stock
    where volume = 0

    DECLARE
        @tmp TABLE
             (
                 stock_id   char(20),
                 trans_id   char(20),
                 amount     int,
                 price      float,
                 acc_amount int
             )

    insert into @tmp
    select t1.stock_id, t1.trans_id, t1.amount, t1.price, isnull(sum(t2.amount), 0)
    from stk.trans t1,
         stk.trans t2
    where t2.date >= t1.date
      and t1.stock_id = t2.stock_id
      and t1.sell_or_buy = 'B'
      and t2.sell_or_buy = 'B'
    group by t1.stock_id, t1.trans_id, t1.amount, t1.price

    update stk.my_stock
    set profit =
                    (select isnull(sum(amount * price), 0)
                     from stk.trans
                     where sell_or_buy = 'S'
                       and stk.trans.stock_id = stk.my_stock.stock_id)
                    - (select isnull(sum(amount * price), 0)
                       from stk.trans
                       where sell_or_buy = 'B'
                         and stk.trans.stock_id = stk.my_stock.stock_id)
                + (select isnull(sum(amount * price), 0)
                   from @tmp
                   where stk.my_stock.stock_id = stock_id
                     and acc_amount <= stk.my_stock.volume)
                + (select isnull(sum((tmp.amount - tmp.acc_amount) * tmp.price), 0)
                   from @tmp tmp
                   where stk.my_stock.stock_id = tmp.stock_id
                     and tmp.acc_amount > stk.my_stock.volume
                     and tmp.acc_amount - tmp.amount <= stk.my_stock.volume)
                + volume * (select isnull(sum(tmp.price), 0)
                            from @tmp tmp
                            where stk.my_stock.stock_id = tmp.stock_id
                              and tmp.acc_amount > stk.my_stock.volume
                              and tmp.acc_amount - tmp.amount <= stk.my_stock.volume)

end
go

-- Test data
insert into stk.trans
values (1, 1, 1, 10, 1000, 'B')
insert into stk.trans
values (2, 1, 2, 11, 500, 'B')
insert into stk.trans
values (3, 1, 3, 12, 800, 'S')
insert into stk.trans
values (4, 1, 4, 12, 1000, 'S')
insert into stk.trans
values (5, 1, 5, 9, 1000, 'B')
insert into stk.trans
values (6, 1, 6, 12, 800, 'S')
insert into stk.trans
values (7, 1, 7, 7, 800, 'S')
