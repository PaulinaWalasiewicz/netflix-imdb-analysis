/* 
=====================================================
02_imdb_matching.sql
Matching Netflix titles with IMDb titles and ratings
=====================================================
*/


/*
=====================================================
1. Prepare IMDb titles
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

-- Check: are the missing titles only the adult ones?
select isAdult, count(*) as adult_count from imdb_titles_raw
where titleType in ('movie', 'tvMovie', 'tvSpecial', 'short', 'tvShort', 'video', 'tvSeries', 'tvMiniSeries')
group by isAdult;
/*
"isAdult","adult_count"
"0",2729369
"1",131612
*/
-- 131,612 adult titles removed, the rest matches imdb_titles exactly.

--How many titles from imdb_titles have ratings?
select count(*) as total_titles, 
    (count(*)-count(averageRating)) as null_ratings_count,
    count(averageRating) as rated_count
from imdb_titles;
/*
"total_titles","null_ratings_count","rated_count"
2729369,1943449,785920
*/

-- =====================================================
-- 2. Baseline: exact match on title + year + type
-- =====================================================

-- Index for faster matching by title and year
create index idx_imdb_titles_match on imdb_titles(primaryTitle, startYear);

-- Take a look at the joined rows
select n.show_id, n.title, n.type, n.release_year, i.tconst, i.primaryTitle, i.startYear,i.averageRating,i.numVotes
from netflix_raw n
left join imdb_titles i
    on n.title = i.primaryTitle
    and n.release_year = i.startYear
    and n.type = i.netflix_type
order by n.show_id
limit 50;
-- Some titles have several IMDb candidates (e.g. "Rush" 2013 has 3).
-- The correct one usually has many more votes (567,924 vs 13).

-- How many Netflix titles have an exact match?
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
-- 5,864 of 8,807 titles matched (66.6%). TV shows match much worse than movies.


-- =====================================================
-- 3. Year rules
-- =====================================================

-- Test: allow any IMDb start year earlier than or equal to the Netflix release year
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

/*
There is much more tv shows being matched when we allow for the release year to be greater 
than or equal to the start year. This makes sense because many tv shows have multiple seasons and 
may have started before they were added to Netflix. Netflix often gives the year of the latest season.

We also got more matched movies. This is because some movies are the same but with a slightly
different release year. Others are different movies with the same title.

So we should use different matching criteria for movies and tv shows. 


*/
--But lets first check

-- Movies matched only with the loose year rule
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
-- 1 year adds 179 movies, 2 years add 27 more, 3 years only 3 more.

-- Movies matched with exactly 2 years difference
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
--Most of them are the same movie, e.g. "Unicorn Store" with 21,676 votes.
--But most "short" matches are wrong: Netflix has a full-length movie, and IMDb matched a random short film with the same title.
--So short and tvShort should only be matched when the Netflix movie is also short (under 40 min).

-- Movies matched with exactly 3 years difference
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
-- Only 3 movies, two of them have no ratings and one has only 18 votes.
-- Decision: 2 years tolerance for movies.


-- =====================================================
-- 4. Combined rules
-- =====================================================


--Lets try to match the Netflix titles with the IMDb titles using the new matching criteria.
-- Movies: up to 2 years difference. TV shows: any earlier start year. Short films only for short movies.

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

-- Overall matching rate (movies + TV shows) increased from 66.6% (5,864 of 8,807) to 77.4% (6,817 of 8,807).
-- Some movies were excluded by the short film rule because their only IMDb match was a short film.


-- =====================================================
-- 5. Title normalization
-- =====================================================


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
/*
Main reasons why titles are not matched:
1. Upper/lower case ("DEATH NOTE", "Stranger than Fiction").
2. Special characters: & instead of "and", curly apostrophe ’ instead of ', ":" vs "-", "…".
3. Non-English titles, IMDb primaryTitle may be in English, the original is in originalTitle.
4. Different title in IMDb ("Zathura" vs "Zathura: A Space Adventure", "Marvel's Luke Cage") - normalization won't fix it.
So I will change all letters to lower case, replace & with "and", remove special characters
and also match by originalTitle.
*/

-- Test the normalization on a few titles
select title, replace(
    replace(
    replace(
    replace(
    replace(
    replace(
    replace(
    replace(
    replace(
    replace(
    replace(lower(title), '&', 'and'),
    ':', ''),
    '?', ''),
    '!', ''),
    ',', ''),
    '.', ''),
    '-', ''),
    '’', ''),
    '''', ''),
    '…', ' '),
    '  ', ' ') as title_norm
from netflix_raw
where title in ('DEATH NOTE', 'Ratchet and Clank', 'Gatao - The Last Stray',
                'Jen Kirkman: Just Keep Livin’?', 'Miranda Sings Live…Your Welcome');

/*
"title","title_norm"
"Ratchet and Clank","ratchet and clank"
"Gatao - The Last Stray","gatao the last stray"
"Miranda Sings Live…Your Welcome","miranda sings live your welcome"
"Jen Kirkman: Just Keep Livin’?","jen kirkman just keep livin"
"DEATH NOTE","death note"
*/
-- "…" is replaced with a space (not removed), so "live…your" does not become "liveyour".


--Add normalised title column to IMdb titles table
alter table imdb_titles add column primary_title_norm text;
alter table imdb_titles add column original_title_norm text;

update imdb_titles
set primary_title_norm = replace(
    replace(
    replace(
    replace(
    replace(
    replace(
    replace(
    replace(
    replace(
    replace(
    replace(lower(primaryTitle), '&', 'and'),
    ':', ''),
    '?', ''),
    '!', ''),
    ',', ''),
    '.', ''),
    '-', ''),
    '’', ''),
    '''', ''),
    '…', ' '),
    '  ', ' '),
original_title_norm = replace(
    replace(
    replace(
    replace(
    replace(
    replace(
    replace(
    replace(
    replace(
    replace(
    replace(lower(originalTitle), '&', 'and'),
    ':', ''),
    '?', ''),
    '!', ''),
    ',', ''),
    '.', ''),
    '-', ''),
    '’', ''),
    '''', ''),
    '…', ' '),
    '  ', ' ');


-- Indexes for faster matching
create index idx_imdb_primary_norm on imdb_titles(primary_title_norm);
create index idx_imdb_original_norm on imdb_titles(original_title_norm);


-- Check the result
select primaryTitle, primary_title_norm, originalTitle, original_title_norm
from imdb_titles
where primaryTitle in ('Death Note', 'Ratchet & Clank', 'Zathura: A Space Adventure');
-- "Ratchet & Clank" -> "ratchet and clank"




-- Save normalized Netflix titles as a table, so the next queries are simple
drop table if exists netflix_norm;
create table netflix_norm as
select *,
    replace(
    replace(
    replace(
    replace(
    replace(
    replace(
    replace(
    replace(
    replace(
    replace(
    replace(lower(title), '&', 'and'),
    ':', ''),
    '?', ''), 
    '!', ''), 
    ',', ''), 
    '.', ''), 
    '-', ''),
    '’', ''), 
    '''', ''), 
    '…', ' '), 
    '  ', ' ') as title_norm
from netflix_raw;


-- =====================================================
-- 6. All matched pairs
-- =====================================================

-- Save all matched pairs (normalized title or original title + all rules) as a table
drop table if exists matches;
create table matches as
select n.show_id, n.title, n.type, n.release_year, n.duration,
       i.tconst, i.primaryTitle, i.originalTitle, i.titleType,
       i.startYear, i.averageRating, i.numVotes
from netflix_norm n
join imdb_titles i
    on (n.title_norm = i.primary_title_norm or n.title_norm = i.original_title_norm)
    and n.type = i.netflix_type
    and ((n.type = 'Movie' and n.release_year - i.startYear between 0 and 2)
         or (n.type = 'TV Show' and i.startYear <= n.release_year))
    and (i.titleType not in ('short', 'tvShort')
         or cast(n.duration as integer) <= 40);


-- How many Netflix titles are matched now?
select type, count(distinct show_id) as matched_titles
from matches
group by type;
/*
"type","matched_titles"
"Movie",5255
"TV Show",2283
*/
-- Movies: 78.0% -> 85.7%, TV shows: 76.0% -> 85.3%.
-- Total: 77.4% (6,817) -> 85.6% (7,538).

-- Check the new matches 
select * from matches
where title <> primaryTitle
order by random()
limit 50;
-- Most of them are good: only different case ("ROMA" - "Roma") or matched by original title
-- ("Hasta los dientes" - "Armed to the Teeth", "Inxeba" - "The Wound").
-- Some are wrong, usually with very few votes ("Scandal" - "Scandal!" from 2005 with 26 votes).

-- Do these titles also have a correct candidate?
select show_id, title, primaryTitle, titleType, startYear, numVotes
from matches
where show_id in ('s7954', 's8695', 's1835', 's2')
order by show_id, numVotes desc;
-- Yes. "Scandal", "War" and "Blood & Water": the correct one has the most votes.
-- But "Start-Up" (2020) would be matched with "StartUp" (2016), because it has more votes (33,233 vs 19,882).
-- After normalization both titles are "startup".


-- =====================================================
-- 7. Choose one IMDb match per Netflix title
-- =====================================================

--Rirst the candidate with exactly the same title, then the one with the most votes
drop table if exists netflix_imdb;
create table netflix_imdb as
with ranked as (
    select *,
        row_number() over (
            partition by show_id
            order by
                case when title = primaryTitle then 0 else 1 end,
                numVotes desc
        ) as rn
    from matches
)
select * from ranked
where rn = 1;

-- Check the problem titles
select show_id, title, primaryTitle, startYear, numVotes
from netflix_imdb
where show_id in ('s7954', 's8695', 's1835', 's2');
/*
"show_id","title","primaryTitle","startYear","numVotes"
"s1835","Start-Up","Start-Up",2020,19882
"s2","Blood & Water","Blood & Water",2020,4875
"s7954","Scandal","Scandal",2012,85188
"s8695","War","War",2007,102272
*/
-- All 4 are correct now.

-- Check: only one row per Netflix title?
select count(*) as total_rows,
       count(distinct show_id) as unique_titles
from netflix_imdb;
/*
"total_rows","unique_titles"
7538,7538
*/
-- Yes. Final result: 7,538 of 8,807 Netflix titles (85.6%) matched with IMDb.
