/* 
=====================================================
01_exploration.sql
Initial exploration of Netflix and IMDb tables
=====================================================
*/

-- Table structures

pragma table_info('netflix_raw');
--show_id,type,title,director,cast,country,date_added,release_year,rating,duration,listed_in,description

pragma table_info('imdb_titles_raw');
-- tconst,titleType,primaryTitle,originalTitle,isAdult,startYear,endYear,runtimeMinutes,genres

pragma table_info('imdb_ratings_raw');
--tconst,averageRating,numVotes

--How many rows are in each table?
select 'netflix_raw' as table_name, count(*) as row_count from netflix_raw
union all
select 'imdb_titles_raw', count(*) from imdb_titles_raw
union all
select 'imdb_ratings_raw', count(*) from imdb_ratings_raw;
/*
"table_name","row_count"
"netflix_raw",8807
"imdb_titles_raw",12844280
"imdb_ratings_raw",1718051
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

--How many titles of each type are in the IMDb table?
select titleType,count(titleType) as type_count
from imdb_titles_raw
group by titleType;
/*
"titleType","type_count"
"movie",758779
"short",1161854
"tvEpisode",9932779
"tvMiniSeries",73428
"tvMovie",156491
"tvPilot",1
"tvSeries",306440
"tvShort",11075
"tvSpecial",60924
"video",331990
"videoGame",50519
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


--How many Netflix movies are shorter than 40 minutes?
select count(*) as short_movies_count
from netflix_raw
where type = 'Movie' and cast(duration as integer) < 40;
--170

--What are the titles, durations, and genres of Netflix movies that are shorter than 40 minutes?
select title,duration, listed_in from netflix_raw 
where type = 'Movie' and cast(duration as integer) < 40
order by cast(duration as integer) asc;
-- Mix of short films, kids' holiday specials and behind-the-scenes content

--What are the titles, durations, and genres of Netflix movies that have a null duration?
select * from netflix_raw 
where type = 'Movie' and cast(duration as integer) is null;
-- 3 Louis C.K. stand-ups: duration was shifted into the rating column

--What are the unique values in the rating column of the Netflix table?
select rating, count(*) as rating_type_count 
from netflix_raw 
GROUP BY rating 
ORDER BY rating_type_count DESC;

/*
Findings - rating column:
- Three rows have the duration mistakenly entered in the rating column (74 min, 84 min, and 66 min). These values should be moved to the duration column, and the rating should be set to NULL.
- There are currently 4 NULL values in the rating column. After fixing the three shifted values, this will increase to 7 NULLs.
- NR (80 entries) and UR (3 entries) represent the same category, so they should be combined into a single Not Rated category.
- TV-Y7-FV (6 entries) is a variant of TV-Y7, so it should be merged with TV-Y7


DECISION: Which IMDb title types to use for matching with Netflix

Netflix 'Movie' - movie, tvMovie, tvSpecial, short, tvShort, video

Netflix 'TV Show' → tvSeries, tvMiniSeries

Excluded: tvEpisode, tvPilot, videoGame

-tvEpisode: represents individual episodes, not full shows; 
- tvPilot, videoGame: not part of the Netflix catalog
  */
