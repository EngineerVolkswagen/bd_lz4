
---1---
create database  SelesDB

use SelesDB

create table Customers(
CustomerID int identity(1,1) primary key,
FullName nvarchar(100) not null,
Email nvarchar(100) unique not null,
RegistrationDate datetime not null default getdate()
)

create table Orders(
OrderID int identity(1,1) primary key,
CustomerID int not null,
OrderTotal float check(OrderTotal > 0) not null,
OrderDate datetime not null default getdate(),
Status nvarchar(20) not null default 'Новый',
constraint FK_Customers foreign key (CustomerID) references Customers(CustomerID)
)

create database LogisticsDB

use LogisticsDB

create table Warehouses(
WarehouseID int identity(1,1) primary key,
Location nvarchar(100) unique not null,
Capacity float not null,
ManagerContact nvarchar(50) not null default 'Не назначен',
CreateDate datetime not null default getdate() 
)

insert into Warehouses (Location, Capacity) values
('Москва, ул. Ленина 10', 5000.0),
('Санкт-Петербург, пр. Мира 5', 3500.0),
('Екатеринбург, ул. Горького 12', 2000.0),
('Казань, ул. Баумана 1', 1500.0),
('Новосибирск, ул. Красная 8', 4000.0);

create table Shipments(
ShipmentID int  identity(1,1) primary key,
WarehouseID int not null,
OrderID int not null,
TrackingCode nvarchar(50) unique not null,
Weight float not null,
DispathDate datetime,
Status nvarchar(20) not null default 'Ожидает отправки',
constraint FK_Warehouses foreign key (WarehouseID) references Warehouses(WarehouseID)
)

insert into Shipments (WarehouseID, OrderID, TrackingCode, Weight) values
(1, 1, 'TRK001MSK', 5.2),
(2, 2, 'TRK002SPB', 1.5),
(1, 4, 'TRK003MSK', 12.0),
(3, 6, 'TRK004EKT', 3.4),
(5, 8, 'TRK005NSK', 0.8),
(2, 10, 'TRK006SPB', 7.1),
(4, 3, 'TRK007KZN', 2.0);

---2---
create function dbo.fn_GetCustomers()
returns table
as
return
(
    select * from Customers 
);

select * from dbo.fn_GetCustomers()



create function dbo.fn_GetOrdersByStatus (@status nvarchar(20))
returns table
as
return
(
    select OrderID, CustomerID, OrderTotal, OrderDate, Status from Orders
    where Status = @status
);


select * from dbo.fn_GetOrdersByStatus('Новый')


create function dbo.fn_GetShipmentsByWarehouse(@wid int)
returns table
as
return
(
    select ShipmentID, WarehouseID, OrderID, TrackingCode, Weight, DispathDate, Status from Shipments
    where WarehouseID = @wid
);

select * from dbo.fn_GetShipmentsByWarehouse(1)

create function dbo.fn_GetOrders()
returns table
as
return
(
    select * from Orders 
);

create function dbo.fn_GetShipments()
returns table
as
return
(
    select * from Shipments
);

---3---
create trigger Orders_AfterUpdate_Logistics
    on Orders
    after insert, update
as
begin
	if update([Status])
		begin
			if not exists (select 1 from LogisticsDB.dbo.Warehouses where WarehouseID = 1)
				begin
					raiserror ('Ошибка, склад с WarehouseID = 1 не найден.', 16, 1)
					return
				end

			insert into LogisticsDB.dbo.Shipments (WarehouseID, OrderID, TrackingCode, [Weight], DispathDate, [Status])
				select 1, inserted.OrderID, 'TRK_' + cast(newid() as nvarchar(40)), 1.0, null, 'Ожидает отправки' from inserted
					join deleted on inserted.OrderID = deleted.OrderID
					where inserted.[Status] = 'Подтвержден'
		end
end

---4---
---4.1---
create procedure InsertCustomers
as
begin
	insert into Customers (FullName, Email) values
	('Иван Иванов', 'ivan@mail.ru'),
	('Анна Смирнова', 'anna@yandex.ru'),
	('Петр Петров', 'petr@gmail.com'),
	('Елена Соколова', 'elena@outlook.com'),
	('Дмитрий Кузнецов', 'dima@list.ru'),
	('Мария Волкова', 'masha@bk.ru'),
	('Сергей Морозов', 'sergey@inbox.ru'),
	('Ольга Лебедева', 'olga@work.com'),
	('Алексей Новиков', 'alex@it.ru'),
	('Наталья Павлова', 'natasha@prime.ru');
end

exec InsertCustomers

select * from fn_GetCustomers()

create procedure InsertOrders
as
begin
	insert into Orders (CustomerID, OrderTotal) values
	(1, 1500.50),
	(2, 2300.00),
	(3, 850.00),
	(4, 12000.75),
	(5, 540.20),
	(6, 3100.00),
	(7, 990.99),
	(8, 7500.00),
	(9, 1200.00),
	(10, 4300.50);
end

exec InsertOrders

select * from dbo.fn_GetOrders()

---4.2---
use SelesDB
select * from fn_GetOrdersByStatus('Подтвержден')
update Orders set Status = 'Подтвержден' where OrderID = 2;
select * from fn_GetOrdersByStatus('Подтвержден')

use LogisticsDB
select * from fn_GetShipments()

---4.3.---
use SelesDB
insert into Orders (CustomerID, OrderTotal) values (1, -10); 
select * from dbo.fn_GetOrders()

---4.4---
select * from dbo.fn_GetCustomers();
select * from dbo.fn_GetOrdersByStatus('Подтвержден');
select * from LogisticsDB.dbo.fn_GetShipmentsByWarehouse(1);

---4.5---
create procedure TestTransaction
as
begin
	begin transaction
		begin try
			update Customers set Email = (select top (1) Email from Customers)
			commit transaction
		end try
		begin catch
			rollback transaction
			raiserror('Ошибка транзакции', 0, 0)
		end catch
end

exec TestTransaction
select * from dbo.fn_GetCustomers()