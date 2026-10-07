/* 
=====================================================
02_imdb_matching.sql
Matching Netflix and IMDb data
=====================================================
*/

--Create a new table with only the relevant IMDb titles (movies and TV shows) and their corresponding Netflix type
drop table if exists imdb_titles;
create table imdb_titles as
select t.tconst, titleType, primaryTitle, originalTitle, runtimeMinutes, genres, averageRating, numVotes,
cast (case when titleType in ('tvSeries', 'tvMiniSeries') then 'TV Show' else 'Movie' end as text) as netflix_type, 
cast(startYear as integer) as startYear
from imdb_titles_raw t
left join imdb_ratings_raw r on t.tconst = r.tconst
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

--How many titles from imdb_titles have ratings?
select count(*) as total_titles, (count(*)-count(averageRating)) as null_ratings_count,count(averageRating) as rated_count
from imdb_titles;
/*
"total_titles","null_ratings_count","rated_count"
2729369,1943449,785920
*/


--How many Netflix titles have matching IMDb titles?
create index idx_imdb_titles_match on imdb_titles(primaryTitle, startYear);

select n.show_id, n.title, n.type, n.release_year, i.tconst, i.primaryTitle, i.startYear,i.averageRating,i.numVotes
from netflix_raw n
left join imdb_titles i
    on n.title = i.primaryTitle
    and n.release_year = i.startYear
    and n.type = i.netflix_type
order by n.show_id
limit 50;

with match_counts as (
    select
        n.type,
        count(distinct n.show_id) as total_titles,
        count(distinct case when i.tconst is not null then n.show_id end) as matched_titles
    from netflix_raw n
    left join imdb_titles i
        on n.title = i.primaryTitle
        and n.release_year = i.startYear
        and n.type = i.netflix_type
    group by n.type
)
select
    type,
    total_titles,
    matched_titles,
    round(100.0 * matched_titles / total_titles, 1) as match_pct
from match_counts
order by type;
/*
"type","total_titles","matched_titles","match_pct"
"Movie",6131,4627,75.5
"TV Show",2676,1237,46.2
*/
-- Baseline: exact match on title + year + type

with match_counts as (
    select
        n.type,
        count(distinct n.show_id) as total_titles,
        count(distinct case when i.tconst is not null then n.show_id end) as matched_titles
    from netflix_raw n
    left join imdb_titles i
        on n.title = i.primaryTitle
        and n.release_year >= i.startYear
        and n.type = i.netflix_type
    group by n.type
)
select
    type,
    total_titles,
    matched_titles,
    round(100.0 * matched_titles / total_titles, 1) as match_pct
from match_counts
order by type;
/*
"type","total_titles","matched_titles","match_pct"
"Movie",6131,4891,79.8
"TV Show",2676,2033,76
*/

--So there is mutch more tv shows being matched when we allow for the release year to be greater 
--than or equal to the start year. This makes sense because many tv shows have multiple seasons and 
--may have started before they were added to Netflix. And netflix does not always add first 
--seazon date as it should be. 

--But we also got more mtched movies. This is because some movies have been re-released in later
-- years, and Netflix may have added the re-release date instead of the original release date.

--So we should use diffrent matching criteria for movies and tv shows. 
--For movies we should use exact match on title + year + type, and for tv shows we should use 
--exact match on title + type, and release year >= start year.

--But lets first chek

select n.title, n.release_year, i.primaryTitle, i.startYear, i.titleType, i.numVotes
from netflix_raw n
join imdb_titles i
    on n.title = i.primaryTitle
    and i.startYear < n.release_year
    and n.type = i.netflix_type
where n.type = 'Movie'
  and not exists (
      select 1
      from imdb_titles i2
      where i2.primaryTitle = n.title
        and i2.startYear = n.release_year
        and i2.netflix_type = n.type
  )
order by n.title
limit 50;

/*
There are a lot of movies with the same name but different startYear. Some of them are decades apart.
So we should use 2 or 3 years difference for movies.
This also removes remakes, because they are usually many years apart from the original.
We can't use numVotes to choose the right movie, because "Animal Crackers" (1930) has more votes than the correct one from 2017.
*/

-- How many movies match with a year tolerance of 0, 1, 2 and 3 years?
select
    count(distinct n.show_id) as total_movies,
    count(distinct case when n.release_year - i.startYear = 0 then n.show_id end) as tol_0,
    count(distinct case when n.release_year - i.startYear between 0 and 1 then n.show_id end) as tol_1,
    count(distinct case when n.release_year - i.startYear between 0 and 2 then n.show_id end) as tol_2,
    count(distinct case when n.release_year - i.startYear between 0 and 3 then n.show_id end) as tol_3
from netflix_raw n
left join imdb_titles i
    on n.title = i.primaryTitle
    and n.release_year - i.startYear between 0 and 3
    and n.type = i.netflix_type
where n.type = 'Movie';
/*
"total_movies","tol_0","tol_1","tol_2","tol_3"
6131,4627,4806,4833,4836
*/

--for 2 yesrs
select n.title, n.release_year,n.duration, i.primaryTitle, i.startYear, i.titleType, i.numVotes
from netflix_raw n
join imdb_titles i
    on n.title = i.primaryTitle
    and n.release_year - i.startYear = 2
    and n.type = i.netflix_type
where n.type = 'Movie'
  and not exists (
      select 1
      from imdb_titles i2
      where i2.primaryTitle = n.title
        and n.release_year - i2.startYear between 0 and 1
        and i2.netflix_type = n.type
  )
order by n.title;
--Most of them are the same movie (festival premiere vs Netflix release), e.g. "Unicorn Store" with 21,676 votes.
--But most "short" matches are wrong: Netflix has a full-length movie, and IMDb matched a random short film with the same title.
--So short and tvShort should only be matched when the Netflix movie is also short (under 40 min).

--for 3 years
select n.title, n.release_year,n.duration, i.primaryTitle, i.startYear, i.titleType, i.numVotes
from netflix_raw n
join imdb_titles i
    on n.title = i.primaryTitle
    and n.release_year - i.startYear = 3
    and n.type = i.netflix_type
where n.type = 'Movie'
  and not exists (
      select 1
      from imdb_titles i2
      where i2.primaryTitle = n.title
        and n.release_year - i2.startYear between 0 and 2
        and i2.netflix_type = n.type
  )
order by n.title;
-- Only return 3 moviestwo has no ratings and one has only 18 so we will use 2 years tolerance for movies.


--Lets try to match the Netflix titles with the IMDb titles using the new matching criteria.
with match_counts as (
    select
        n.type,
        count(distinct n.show_id) as total_titles,
        count(distinct case when i.tconst is not null then n.show_id end) as matched_titles
    from netflix_raw n
    left join imdb_titles i
        on n.title = i.primaryTitle
        and n.type = i.netflix_type
        and((n.type = 'Movie' and n.release_year - i.startYear between 0 and 2)
            or
            (n.type = 'TV Show' and i.startYear <= n.release_year)
        )
        and(
            i.titleType not in ('short','tvShort')
            or cast(n.duration as integer) <= 40
        )
    group by n.type
)
select
    type,
    total_titles,
    matched_titles,
    round(100.0 * matched_titles / total_titles, 1) as match_pct
from match_counts
order by type;
/*
"type","total_titles","matched_titles","match_pct"
"Movie",6131,4784,78
"TV Show",2676,2033,76
*/
-- Rules: for movies, the release year can differ by up to 2 years. For TV shows, any IMDb start year earlier 
--than or equal to the Netflix release year is allowed. Short films are only considered for movies shorter than 40 minutes.
-- The matching rate increased from 66.6% (5,864 titles) to 77.4% (6,817 titles).
-- 49 movies were excluded by the short film rule because their only IMDb match was a short film.


-- Sample of unmatched Netflix titles
select n.show_id, n.title, n.type, n.release_year
from netflix_raw n
left join imdb_titles i
    on n.title = i.primaryTitle
    and n.type = i.netflix_type
    and ((n.type = 'Movie' and n.release_year - i.startYear between 0 and 2)
        or
        (n.type = 'TV Show' and i.startYear <= n.release_year)
    )
    and (
        i.titleType not in ('short','tvShort')
        or cast(n.duration as integer) <= 40
    )
where i.tconst is null
order by random()
limit 50;