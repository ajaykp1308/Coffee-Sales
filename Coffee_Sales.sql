select * from coffee_shop_sales;

-- addding a new column to transform text format date into date format
alter table coffee_shop_sales add transaction_date_new date;

-- extracting dates into new column as as date format yyyy-mm-dd
update coffee_shop_sales
set transaction_date_new = convert(date,cast(transaction_date as varchar(20)),103);

-- addding a new column to transform text format time into time format
alter table coffee_shop_sales add transaction_time_new time;

--extracting dates into a new column as a time format hh:mm:ss
update coffee_shop_sales
set transaction_time_new = convert(time, cast(transaction_time as varchar(20)));

--dropping old columns of time and date
alter table coffee_shop_sales drop column transaction_date, transaction_time;

--renaming the newer columns of date and time to older column names
exec sp_rename 'coffee_shop_sales.transaction_date_new', 'transaction_date', 'column'
exec sp_rename 'coffee_shop_sales.transaction_time_new', 'transaction_time', 'column';

--finding the sales for all months
select MONTH(transaction_date) as Month_Num, ceiling(sum(unit_price*transaction_qty)) as Total_Sales
from coffee_shop_sales
group by MONTH(transaction_date) 
order by MONTH(transaction_date);

--finding percentage increase in sales for every month comparing to previous month
--type 1
select MONTH(transaction_date) as Month_Num,
ceiling(sum(unit_price*transaction_qty)) as Total_Sales,
(sum(unit_price*transaction_qty) - LAG(sum(unit_price*transaction_qty),1) over (order by month(transaction_date))) * 100 /
(LAG(sum(unit_price*transaction_qty),1) over (order by month(transaction_date))) as Mom_Inrease_Percentage
from coffee_shop_sales
group by MONTH(transaction_date)
order by MONTH(transaction_date);
--type 2
WITH MonthlySales AS (
    SELECT 
        MONTH(transaction_date) AS Month_Num,
        CEILING(SUM(unit_price * transaction_qty)) AS Total_Sales
    FROM coffee_shop_sales
    GROUP BY MONTH(transaction_date)
)
SELECT 
    Month_Num,
    Total_Sales,
    ROUND(
        (Total_Sales - LAG(Total_Sales, 1) OVER (ORDER BY Month_Num)) * 100.0 /
        NULLIF(LAG(Total_Sales, 1) OVER (ORDER BY Month_Num), 0),
        2
    ) AS Mom_Increase_Percentage
FROM MonthlySales
ORDER BY Month_Num;


--finding no.of orders for every month
select month(transaction_date) as Month_Num, count(transaction_id) as Total_No_of_Orders
from coffee_shop_sales
group by month(transaction_date)
order by month(transaction_date);

--finding percentage increase in orders for every month comparing to previous month
--type 1
select MONTH(transaction_date) as Month_Num,
count(transaction_id) as Total_No_of_Orders,
(count(transaction_id) - lag(count(transaction_id),1) over (order by month(transaction_date))) * 100 /
(lag(count(transaction_id),1) over (order by month(transaction_date))) as Mom_Increase_Percentage 
from coffee_shop_sales
group by MONTH(transaction_date)
order by MONTH(transaction_date);
--type 2
with monthly_orders as (
select MONTH(transaction_date) as Month_Num,
cast(count(transaction_id) as decimal) as Total_No_of_Orders
from coffee_shop_sales
group by MONTH(transaction_date)
)
select Month_Num, 
Total_No_of_Orders,
(Total_No_of_Orders-lag(Total_No_of_Orders,1) over (order by Month_Num)) * 100/
(lag(Total_No_of_Orders,1) over (order by Month_Num)) as Mom_Increase_Percentage
from monthly_orders
order by Month_Num;

--finding quantity sold for every month
select 
	month(transaction_date) as Month_Num,
	sum(transaction_qty) as Quantity_Sold
from coffee_shop_sales
group by month(transaction_date)
order by month(transaction_date);

--finding increase in quantity sold every month compared to previous month
with monthly_quantity as (
select 
	month(transaction_date) as Month_Num,
	sum(transaction_qty) as Quantity_Sold
from coffee_shop_sales
group by month(transaction_date)
)
select
	Month_Num,
	Quantity_Sold,
	(Quantity_Sold-lag(Quantity_Sold,1) over (order by Month_Num)) * 100.0/
	(lag(Quantity_Sold,1) over (order by Month_Num)) as Mom_Increase_Percentage
from monthly_quantity;

-- sales , orders and quantity on the date 2023-05-18 (yyyy-mm-dd)
select 
	sum(unit_price*transaction_qty) as Sales,
	count(transaction_id) as Orders,
	sum(transaction_qty) as Quantity
from 
	coffee_shop_sales
where 
	transaction_date = '2023-05-18';

-- sales , orders and quantity in thousands(K) on the date 2023-05-18 (yyyy-mm-dd)
select 
	concat(round(sum(unit_price*transaction_qty)/1000.0,1),'K') as Sales,
	CONCAT( cast(round(count(transaction_id)/1000.0,1) as float), 'K') as Orders,
	concat(cast(round(sum(transaction_qty)/1000.0,1) as float),'K') as Quantity
from 
	coffee_shop_sales
where 
	transaction_date = '2023-05-18';

--AVG SALES TREND OVER PERIOD

with Sales as (
	select 
		transaction_date as d,
		sum(unit_price*transaction_qty) as daily_sales
	from
		coffee_shop_sales
	group by
		transaction_date
)
select
	month(d) as transaction_month,
	avg(daily_sales) as Average_Sales
from
	Sales
group by 
	month(d)
order by
	transaction_month;

--DAILY SALES FOR MONTH SELECTED

with Sales as (
	select 
		transaction_date as d,
		sum(unit_price*transaction_qty) as daily_sales
	from
		coffee_shop_sales
	group by
		transaction_date
)
select
	month(d) as Month_of_The_Year,
	DAY(d) as Day_of_The_Month,
	round(daily_sales,1) as Daily_Sales
from
	Sales				
order by 
	d;

--COMPARING DAILY SALES WITH AVERAGE SALES – IF GREATER THAN “ABOVE AVERAGE” and LESSER THAN “BELOW AVERAGE”

with Sales as (
	select 
		transaction_date as d,
		sum(unit_price*transaction_qty) as daily_sales,
		avg(sum(unit_price*transaction_qty)) over() as average_sales
	from
		coffee_shop_sales
	group by
		transaction_date
)
select
	month(d) as Month_of_The_Year,
	DAY(d) as Day_of_The_Month,
	round(daily_sales,1) as Daily_Sales,
	case
		when daily_sales > average_sales then 'ABOVE AVERAGE'
		when daily_sales < average_sales then 'BELOW AVERAGE'
		else 'Average'
	end as Sales_Status
from 
	Sales
order by
	d;


-- count of sales Status from all dates
select 
	distinct(Sales_Status),
	count(Sales_Status) as count
from (
	select
		month(d) as Month_of_The_Year,
		DAY(d) as Day_of_The_Month,
		round(daily_sales,1) as Daily_Sales,
		case
			when daily_sales > average_sales then 'ABOVE AVERAGE'
			when daily_sales < average_sales then 'BELOW AVERAGE'
			else 'Average'
		end as Sales_Status
	from 
		(select 
			transaction_date as d,
			sum(unit_price*transaction_qty) as daily_sales,
			avg(sum(unit_price*transaction_qty)) over() as average_sales
		from
			coffee_shop_sales
		group by
			transaction_date) as Sales
		) as all_sales
group by Sales_Status;

-- SALES BY WEEKDAY / WEEKEND OVER MONTHS

select 
	month(transaction_date) as month_num,
	case
		when DATEPART(WEEKDAY,transaction_date) in (1,7) then 'Weekend'
		else 'Weekday'
	end as day_type,
	sum(unit_price*transaction_qty) as sales
from 
	coffee_shop_sales
group by 
	month(transaction_date),
	case
		when DATEPART(WEEKDAY,transaction_date) in (1,7) then 'Weekend'
		else 'Weekday'
	end
order by
	month_num;

--SALES BY STORE LOCATION

select 
	datename(MONTH,transaction_date) as month, 
	store_location,
	sum(unit_price*transaction_qty) as Sales
from
	coffee_shop_sales
group by 
	store_location,
	datename(MONTH,transaction_date)
order by 
	month, Sales desc;

--SALES BY PRODUCT CATEGORY

select 
	datename(MONTH,transaction_date) as month, 
	product_category,
	round(sum(unit_price*transaction_qty),1) as Sales
from
	coffee_shop_sales
group by 
	product_category,
	datename(MONTH,transaction_date)
order by 
	month, Sales desc;

-- SALES BY PRODUCTS (TOP 10)

with monthly_sales as (
	select 
		FORMAT(transaction_date,'MM') as month, 
		product_type as product,
		round(sum(unit_price*transaction_qty),1) as Sales,
		ROW_NUMBER() over (
			partition by (FORMAT(transaction_date,'MM')) 
			order by sum(unit_price*transaction_qty) desc
			) as rn
	from 
		coffee_shop_sales
	group by 
		product_type,
		FORMAT(transaction_date,'MM')
)
select 
	month,
	product,
	Sales
from
	monthly_sales
where 
	rn < 11;

-- sales, quantity, orders on tuesdays in month may between 8-9 am

select 
	round(sum(unit_price*transaction_qty),0) as total_sales,
	count(transaction_id) as no_of_orders,
	sum(transaction_qty) as quantity_sold
from 
	coffee_shop_sales
where
	DATEPART(MONTH,transaction_date) = 5 and
	DATEPART(WEEKDAY,transaction_date) = 3 and
	DATEPART(HOUR, transaction_time) = 8;

-- TO GET SALES ANY WEEKDAY FOR MONTH OF MAY
-- type1
with monthwise_weekly_day_sales as (
	select 
		datepart(month,transaction_date) as month_num,
		case
			when DATEPART(weekday, transaction_date) = 2 then 'Monday'
			when DATEPART(weekday, transaction_date) = 3 then 'Tuesday'
			when DATEPART(weekday, transaction_date) = 4 then 'Wednesday'
			when DATEPART(weekday, transaction_date) = 5 then 'Thursday'
			when DATEPART(weekday, transaction_date) = 6 then 'Friday'
			when DATEPART(weekday, transaction_date) = 7 then 'Saturday'
			else 'Sunday'
		end as Weekday_Name,
		round(sum(unit_price*transaction_qty),0) as total_sales
	from
		coffee_shop_sales
	group by 
		DATEPART(weekday, transaction_date),
		datepart(month,transaction_date)
)
select 
	month_num,
	Weekday_Name,
	total_sales
from
	monthwise_weekly_day_sales
where
	month_num = 5;
-- type2
with monthwise_weekly_day_sales as (
	select 
		datepart(month,transaction_date) as month_num,
		DATEPART(weekday, transaction_date) as weekday_num,
		case
			when DATEPART(weekday, transaction_date) = 2 then 'Monday'
			when DATEPART(weekday, transaction_date) = 3 then 'Tuesday'
			when DATEPART(weekday, transaction_date) = 4 then 'Wednesday'
			when DATEPART(weekday, transaction_date) = 5 then 'Thursday'
			when DATEPART(weekday, transaction_date) = 6 then 'Friday'
			when DATEPART(weekday, transaction_date) = 7 then 'Saturday'
			else 'Sunday'
		end as Weekday_Name,
		round(sum(unit_price*transaction_qty),0) as total_sales
	from
		coffee_shop_sales
	group by 
		DATEPART(weekday, transaction_date),
		datepart(month,transaction_date)
)
select 
	month_num,
	Weekday_Name,
	total_sales
from
	monthwise_weekly_day_sales
order by
	month_num ,weekday_num;

-- TO GET SALES FOR ALL HOURS FOR ANY MONTH

select
	DATEPART(MONTH,transaction_date) as month_num,
	DATEPART(hour,transaction_time) as sale_hour,
	round(sum(unit_price*transaction_qty),0) as total_sales
from 
	coffee_shop_sales
group by 
	DATEPART(MONTH,transaction_date),
	DATEPART(hour,transaction_time)
order by
	DATEPART(MONTH,transaction_date),
	DATEPART(hour,transaction_time)