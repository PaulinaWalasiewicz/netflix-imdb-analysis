/*
=====================================================
03_cleaning.sql
Cleaning Netflix data and adding IMDb ratings
=====================================================
*/

-- =====================================================
-- 1. Rating and duration
-- =====================================================

-- Test: fix shifted duration and merge rating categories
select title, rating, duration, 
    case when rating like '% min' then NULL
        when rating = 'UR' then 'NR'
        when rating ='TV-Y7-FV' then 'TV-Y7'
        else rating end as rating_clean,
    case when rating like '% min' then rating
        else duration end as duration_clean
from netflix_raw
where title like 'Louis C.K%' or rating in ('UR', 'TV-Y7-FV');
-- Louis C.K. stand-ups: rating_clean is NULL, duration_clean has their duration.
-- UR -> NR, TV-Y7-FV -> TV-Y7. Other titles keep their duration.


-- =====================================================
-- 2. Duration as numbers
-- =====================================================

-- Test: duration as numbers. Movies get duration_min, TV shows get the number of seasons.
with step1 as(
    select title, rating, duration, "type",
    case when rating like '% min' then NULL
        when rating = 'UR' then 'NR'
        when rating ='TV-Y7-FV' then 'TV-Y7'
        else rating end as rating_clean,
    case when rating like '% min' then rating
        else duration end as duration_clean
from netflix_raw
where title like 'Louis C.K%' or rating in ('UR', 'TV-Y7-FV') or title like 'Stranger%'

)select title, rating, duration, "type",rating_clean,duration_clean,
        case when "type" = 'Movie' then cast(duration_clean as integer) end as duration_min,
        case when "type" = 'TV Show' then cast(duration_clean as integer) end as seasons
from step1;

-- Louis C.K. stand-ups now have their duration (74, 84, 66 min) taken from the rating column.

/*
"title","rating","duration","type","rating_clean","duration_clean","duration_min","seasons"
"Stranger","TV-MA","2 Seasons","TV Show","TV-MA","2 Seasons","",2
"Strangers from Hell","TV-MA","1 Season","TV Show","TV-MA","1 Season","",1
"Stranger Things","TV-14","3 Seasons","TV Show","TV-14","3 Seasons","",3
"Louis C.K. 2017","74 min","","Movie","","74 min",74,""
"Louis C.K.: Hilarious","84 min","","Movie","","84 min",84,""
"Louis C.K.: Live at the Comedy Store","66 min","","Movie","","66 min",66,""
"Dear Dracula","TV-Y7-FV","43 min","Movie","TV-Y7","43 min",43,""
"Immoral Tales","UR","103 min","Movie","NR","103 min",103,""
"LEGO Ninjago: Masters of Spinjitzu: Day of the Departed","TV-Y7-FV","44 min","Movie","TV-Y7","44 min",44,""
"Leo the Lion","TV-Y7-FV","78 min","Movie","TV-Y7","78 min",78,""
"Little Singham aur Kaal ka Mahajaal","TV-Y7-FV","68 min","Movie","TV-Y7","68 min",68,""
"Motu Patlu: King of Kings","TV-Y7-FV","109 min","Movie","TV-Y7","109 min",109,""
"Oh No! It's an Alien Invasion","TV-Y7-FV","2 Seasons","TV Show","TV-Y7","2 Seasons","",2
"Sex Doll","UR","103 min","Movie","NR","103 min",103,""
"Stranger than Fiction","PG-13","113 min","Movie","PG-13","113 min",113,""
"You Don't Mess with the Zohan","UR","113 min","Movie","NR","113 min",113,""
*/


-- =====================================================
-- 3. Year added to Netflix
-- =====================================================

-- Test: take the last 4 characters of date_added (e.g. "September 25, 2021" -> 2021).
-- trim() is needed, because some dates have extra spaces (e.g. " May 31, 2015").
with step1 as(
    select title, rating, duration, "type", date_added,
    case when rating like '% min' then NULL
        when rating = 'UR' then 'NR'
        when rating ='TV-Y7-FV' then 'TV-Y7'
        else rating end as rating_clean,
    case when rating like '% min' then rating
        else duration end as duration_clean
from netflix_raw
where title like 'Louis C.K%' or rating in ('UR', 'TV-Y7-FV') or title like 'Stranger%'

)select title, rating, duration, "type",rating_clean,duration_clean,date_added,
        case when "type" = 'Movie' then cast(duration_clean as integer) end as duration_min,
        case when "type" = 'TV Show' then cast(duration_clean as integer) end as seasons,
        cast(substr(trim(date_added),-4) as integer) as year_added
from step1;

-- Check the year range on all titles
with step1 as(
    select title, rating, duration, "type", date_added,
    case when rating like '% min' then NULL
        when rating = 'UR' then 'NR'
        when rating ='TV-Y7-FV' then 'TV-Y7'
        else rating end as rating_clean,
    case when rating like '% min' then rating
        else duration end as duration_clean
from netflix_raw)
select
    min(year_added) as min_year,
    max(year_added) as max_year,
    count(*) - count(year_added) as null_years
from (
    select cast(substr(trim(date_added), -4) as integer) as year_added
    from step1
);
/*
"min_year","max_year","null_years"
2008,2021,10
*/
-- year_added from 2008 to 2021, 10 NULLs (same as missing date_added in 01_exploration.sql).

-- =====================================================
-- 4. Create the clean table
-- =====================================================

-- All fixes together + IMDb rating and votes.
-- left join: titles without an IMDb match are kept (with NULL rating).
drop table if exists netflix_clean;
create table netflix_clean as
with step1 as (
    select *,
    case when rating like '% min' then NULL
        when rating = 'UR' then 'NR'
        when rating ='TV-Y7-FV' then 'TV-Y7'
        else rating end as rating_clean,
    case when rating like '% min' then rating
        else duration end as duration_clean
from netflix_raw)
select
    s.show_id,
    s."type",
    s.title,
    s.director,
    s."cast",
    s.country,
    s.release_year,
    cast(substr(trim(date_added), -4) as integer) as year_added,
    s.rating_clean as rating,
    case when s."type" = 'Movie' then cast(duration_clean as integer) end as duration_min,
    case when s."type" = 'TV Show' then cast(duration_clean as integer) end as seasons,
    s.listed_in,
    s.description,
    i.tconst,
    i.averageRating as imdb_rating,
    i.numVotes as imdb_votes
from step1 s
left join netflix_imdb i on s.show_id = i.show_id;

--Are all titles kept and how many have a rating?
select count(*) as total_rows,
       count(imdb_rating) as with_rating
from netflix_clean;
/*
"total_rows","with_rating"
8807,7483
*/
-- All 8,807 Netflix titles are kept. 7,483 have an IMDb rating
-- (7,538 matched, 55 of them have no rating in IMDb).