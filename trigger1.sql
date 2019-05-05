-- Trigger task 1: stocks

create database stocks;
go

use stocks;
go

create schema stk;
go

-- Create tables
create table stk.my_stock
(
    stock_id   char(20)   not null,
	volume int,
	avg_price float,
	profit float,
    primary key (stock_id),
)
go

create table stk.trans
(
    trans_id    char(20)   not null,
	stock_id    char(20),
	date        date,
	price       float,
	amount      int,
	sell_or_buy char(10),
    primary key (trans_id),
	check (sell_or_buy in ('sell', 'buy')),
)
go

drop trigger stk.TRIG_trans_update
go

-- Create trigger: update my_stock after records insterted into trans
create trigger TRIG_trans_update
	on stk.trans
	after insert
	as
begin
	update stk.my_stock
	set avg_price = avg_price * volume +
		(
			select isnull(sum(amount * price), 0)
			from inserted ins
			where ins.sell_or_buy = 'buy'
			and ins.stock_id = stk.my_stock.stock_id
		) - 
		(
			select isnull(sum(amount * price), 0)
			from inserted ins
			where ins.sell_or_buy = 'sell'
			and ins.stock_id = stk.my_stock.stock_id
		)

	update stk.my_stock
	set volume = volume +
		(
			select isnull(sum(amount), 0)
			from inserted ins
			where ins.sell_or_buy = 'buy'
			and ins.stock_id = stk.my_stock.stock_id
		) - 
		(
			select isnull(sum(amount), 0)
			from inserted ins
			where ins.sell_or_buy = 'sell'
			and ins.stock_id = stk.my_stock.stock_id
		)

	update stk.my_stock
	set avg_price = avg_price / volume
	where volume > 0

	DECLARE @tmp TABLE
	(
	  stock_id char(20), 
	  trans_id char(20),
	  amount int,
	  price float,
	  acc_amount int
	)

	insert into @tmp
	select t1.stock_id, t1.trans_id, t1.amount, t1.price, sum(t2.amount)
	from stk.trans t1, stk.trans t2
	where t2.date >= t1.date
	and t1.stock_id = t2.stock_id
	and t1.sell_or_buy = 'buy'
	and t2.sell_or_buy = 'buy'
	group by t1.stock_id, t1.trans_id, t1.amount, t1.price

	update stk.my_stock
	set profit =
	( select isnull(sum(amount * price), 0) from stk.trans
	  where sell_or_buy = 'sell' and stk.trans.stock_id = stk.my_stock.stock_id )
	- ( select isnull(sum(amount * price), 0) from stk.trans
	    where sell_or_buy = 'buy' and stk.trans.stock_id = stk.my_stock.stock_id )
	+ ( select isnull(sum(amount * price), 0) from @tmp where stk.my_stock.stock_id = stock_id and acc_amount <= volume)
	+ ( select sum((tmp.amount - tmp.acc_amount + stk.my_stock.volume) * tmp.price)
		from @tmp tmp
		where stk.my_stock.stock_id = tmp.stock_id and tmp.acc_amount > stk.my_stock.volume and tmp.acc_amount - tmp.amount <= stk.my_stock.volume )

end
go

-- Test
delete from stk.my_stock
delete from stk.trans
insert into stk.my_stock values ('001', 0, 0, 0);
insert into stk.my_stock values ('002', 0, 0, 0);
insert into stk.my_stock values ('003', 0, 0, 0);
insert into stk.my_stock values ('004', 0, 0, 0);
insert into stk.trans values ('T1', '001', '5-1-2019', 2.3, 10, 'buy');
insert into stk.trans values ('T2', '001', '5-2-2019', 2.5, 10, 'buy');
insert into stk.trans values ('T3', '002', '5-3-2019', 2.0, 5, 'buy');
insert into stk.trans values ('T4', '002', '5-4-2019', 3.0, 10, 'buy');
insert into stk.trans values ('T5', '002', '5-5-2019', 4.0, 5, 'sell');

select * from stk.my_stock;
select * from stk.trans;
