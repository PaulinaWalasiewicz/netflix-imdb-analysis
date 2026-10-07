/* 
=====================================================
02_imdb_matching.sql
Matching Netflix and IMDb data
=====================================================
*/

--Create a new table with only the relevant IMDb titles (movies and TV shows) and their corresponding Netflix type
drop table if exists imdb_titles;
create table imdb_titles as
select tconst, titleType, primaryTitle, originalTitle, runtimeMinutes, genres, 
cast (case when titleType in ('tvSeries', 'tvMiniSeries') then 'TV Show' else 'Movie' end as text) as netflix_type, 
cast(startYear as integer) as startYear
from imdb_titles_raw
where titleType in ('movie', 'tvMovie', 'tvSpecial', 'short', 'tvShort', 'video', 'tvSeries', 'tvMiniSeries')
and isAdult = '0';

--Take a look at the first 5 rows of the new table
select * from imdb_titles limit 5;

--How many titles are in new columns of the new table?
select netflix_type, count(*) as type_count
from imdb_titles
group by netflix_type;
/*
"netflix_type","type_count"
"Movie",2353142
"TV Show",376227
*/


select isAdult, count(*) as adult_count from imdb_titles_raw
where titleType in ('movie', 'tvMovie', 'tvSpecial', 'short', 'tvShort', 'video', 'tvSeries', 'tvMiniSeries')
group by isAdult;
-- Check: 131,612 adult titles removed, the rest matches imdb_titles exactly.
