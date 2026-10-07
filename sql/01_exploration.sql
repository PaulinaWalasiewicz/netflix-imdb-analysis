/* 
=====================================================
01_exploration.sql
Initial exploration of Netflix and IMDb tables
=====================================================
*/

-- Table structures

pragma table_info('netflix_raw');
--show_id,type,title,director,cast,country,date_added,release_year,rating,duration,listed_in,description

pragma table_info('imdb_titles');
-- tconst,titleType,primaryTitle,originalTitle,isAdult,startYear,endYear,runtimeMinutes,genres

pragma table_info('imdb_ratings');
--tconst,averageRating,numVotes

--How many rows are in each table?
select 'netflix_raw' as table_name, count(*) as row_count from netflix_raw
union all
select 'imdb_titles', count(*) from imdb_titles
union all
select 'imdb_ratings', count(*) from imdb_ratings;
/*
"table_name","row_count"
"netflix_raw",8807
"imdb_titles",1138647
"imdb_ratings",1718051
*/

-- How many titles of each type are in the Netflix table?
select type,count(type) as type_count
from netflix_raw
group by type;
/*
"type","type_count"
"Movie",6131
"TV Show",2676
*/

-- How many null values are in columns of the Netflix table?
select count(*) as total_rows, 
    (count(*) - count(director)) as director_null, 
    (count(*) - count("cast")) as cast_null, 
    (count(*) - count(country)) as country_null, 
    (count(*) - count(date_added)) as date_added_null
from netflix_raw;
/*
"total_rows","director_null","cast_null","country_null","date_added_null"
8807,2634,825,831,10
*/

-- What is the range of release years in the Netflix table?
select max(release_year) as max_release_year, min(release_year) as min_release_year
from netflix_raw;
/*
"max_release_year","min_release_year"
2021,1925
*/
