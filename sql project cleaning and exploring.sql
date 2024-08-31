--  DATA CLEANING 

-- creating a staging table to work on a copy of the orignal data 


drop table if exists layoff_staging ;

create table if not exists layoff_staging 
like layoffs ;

--inserting data into table

insert layoff_staging 
select * 
from layoffs ;

select * from layoff_staging ;

select * , row_number ()
over (partition by company,location, industry , total_laid_off,percentage_laid_off, `date`, stage, country, funds_raised_millions)
as row_num 
from layoff_staging 
;

---removing duplicates  

select * 
from layoff_staging ;

with duplicate_cte as
(select * , row_number ()
over (partition by company,location, industry , total_laid_off,percentage_laid_off, `date`, stage, country, funds_raised_millions)
as row_num 
from layoff_staging )

select * from duplicate_cte 
where row_num > 1 ;

---creating another staging table store cleaned data

drop table if exists layoff_staging2 ;

CREATE TABLE `layoff_staging2` (
  `company` text,
  `location` text,
  `industry` text,
  `total_laid_off` int DEFAULT NULL,
  `percentage_laid_off` text,
  `date` text,
  `stage` text,
  `country` text,
  `funds_raised_millions` int DEFAULT NULL,
  `row_num` int 
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


--copying data form the first staging table and adding a new column row_num to identify duplicate data

select * from layoff_staging2 ;

insert into layoff_staging2 
(select * , row_number ()
over (partition by company,location, industry , total_laid_off,percentage_laid_off, `date`, stage, country, funds_raised_millions)
as row_num 
from layoff_staging )
;


select * from layoff_staging2 
where row_num > 1 ;

delete  from layoff_staging2 
where row_num > 1 ;



## STANDARDIZING DATA 


-- using trim function to remove blank spaces
	
select company , trim(company)
from layoff_staging2 ;

update layoff_staging2
set company = trim(company) ;


--- using like function to merge the misspelled data 


select distinct industry
from layoff_staging2 ;

update  
layoff_staging2
set `industry` = 'Crypto' 
where `industry` like 'Crypto%' ;


--- using trim trailing to remove the . from end 


select distinct country
from layoff_staging2 
order by 1 ;

select distinct country , trim(trailing '.' from country)
from layoff_staging2 
order by 1 ;

update layoff_staging2 
set country = 'United States'
where country like '%United States%' ;

--converting the string to date format 

select `date` ,
str_to_date(`date`,'%m/%d/%Y')
from layoff_staging2 ;

update  layoff_staging2
set `date` = str_to_date(`date`,'%m/%d/%Y') 
;
alter table layoff_staging2
modify column `date` date;


---removing null or blanks 

select *
from layoff_staging2 
where total_laid_off is null 
and percentage_laid_off is null ;

select * 
from layoff_staging2
where industry is null 
or industry = '' ;

select * 
from layoff_staging2
where company = 'Airbnb' ;


--- changing the missing values and empty values to null 


update layoff_staging2
set industry = null
where industry = '' ;


---self joining the table where company name is same and copying the filling the missing values from relevent data 


select * 
from layoff_staging2 as t1
join layoff_staging2 as t2
on t1.company = t2.company
where t1.industry is null 
and t2.industry is not null ; 

update layoff_staging2 t1 
join layoff_staging2 t2 
	on t1.company = t2.company
set t1.industry = t2.industry 
where t1.industry is null 
and t2.industry is not null ; 

---deleting the rows where too much data is missing

delete
from layoff_staging2 
where total_laid_off is null
and percentage_laid_off is null ;

---  removing the row_num colummn because there is no use for it anymre 

alter table layoff_staging2
drop column row_num ;

---EXPLORING DATA 



SELECT MAX (total_laid_off), max(percentage_laid_off)
from layoff_staging2 
;

-- shows the companies that closed entirely and ranking them based on the funds raised in descending ordrer


select * 
from layoff_staging2
where percentage_laid_off = 1
order by funds_raised_millions desc ;


--- numner of total layoff done by the company overall and ranking them based on the sum of total laid off 


select company , sum(total_laid_off) 
from layoff_staging2
group by company
order by 2 desc ;


--- total number of layoff in each country ranked highest to lowest


select country , sum(total_laid_off) 
from layoff_staging2
group by country
order by 2 desc ;


--- total number of layoff ranked by year from highestv to loweest 


select year(`date`), sum(total_laid_off) 
from layoff_staging2
group by year(`date`)
order by 1 desc ;


--- using the substring function to extract the total number of layoff in each month 
---also ranking them in chronollogical order of month 

select substring(`date`,1,7 ) `month`, sum(total_laid_off)
from layoff_staging2
where substring(`date`,1,7 ) is not  null
group by `month` 
order by 1 ;


--using rolling total function to showcase the icrease the layoff gradually 


with rolling_total as 
(select substring(`date`,1,7 ) `month`, sum(total_laid_off) as total_off
from layoff_staging2
where substring(`date`,1,7 ) is not  null
group by `month` 
order by 1 
)
select `month` , total_off,
 sum(total_off) over (order by `month`) as rolling_total
from rolling_total ;


---ranking companies by layoff within each year

select company ,year(`date`) ,sum(total_laid_off) 
from layoff_staging2
group by company , year(`date`)
order by 3 desc ;

with company_year (company , years, total_laid_off) as
(
select company ,year(`date`) ,sum(total_laid_off) 
from layoff_staging2
group by company , year(`date`)
order by 3 desc 
), 
company_year_rank as 
(
select *, dense_rank () over (partition by years  order by total_laid_off desc) as ranking
 from company_year
 where years is not null 

 )
 select * from company_year_rank
 where ranking < 5
 ;
