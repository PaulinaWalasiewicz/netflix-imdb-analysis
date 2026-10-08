/*
=====================================================
04_analysis.sql
Analysis of Netflix titles and their IMDb ratings
=====================================================
*/


-- =====================================================
-- 1. Movies vs TV shows over time
-- =====================================================

-- How many movies and TV shows were added to Netflix each year?
select
    year_added,
    count(case when "type" = 'Movie' then 1 end) as movies,
    count(case when "type" = 'TV Show' then 1 end) as tv_shows,
    round(100.0 * count(case when "type" = 'TV Show' then 1 end) / count(*), 1) as tv_show_pct
from netflix_clean
where year_added is not null
group by year_added
order by year_added;

/*
"year_added","movies","tv_shows","tv_show_pct"
2008,1,1,50
2009,2,0,0
2010,1,0,0
2011,13,0,0
2012,3,0,0
2013,6,5,45.5
2014,19,5,20.8
2015,56,26,31.7
2016,253,176,41
2017,839,349,29.4
2018,1237,412,25
2019,1424,592,29.4
2020,1284,595,31.7
2021,993,505,33.7
*/

-- Before 2015 Netflix added very few titles, so these years are too small to compare.
-- Since 2016 the number of new titles grew fast: from 429 (2016) to 2016 (2019).
-- The share of TV shows is not growing steadily: 41% in 2016, down to 25% in 2018, then up again every year to 33.7% in 2021.
-- The data ends in September 2021, so 2021 is not a full year.
-- That is why we compare percentages, not the number of titles.


-- =====================================================
-- 2. New movies or older catalog?
-- =====================================================

-- How many years pass between release and adding to Netflix?
select
    min(year_added - release_year) as min_gap,
    max(year_added - release_year) as max_gap
from netflix_clean;
/*
"min_gap","max_gap"
-3,93
*/

-- Which titles were added before their release year?
select title, "type", release_year, year_added,
       year_added - release_year as gap
from netflix_clean
where year_added - release_year < 0
order by gap;

-- 14 titles were added before their release year: 12 TV shows and 2 movies.
-- For TV shows release_year is the year of the latest season, not the premiere
-- (e.g. "Sense8": added in 2016, release_year 2018).
-- So the gap between release and adding to Netflix is only analyzed for movies.

-- How new are the movies added each year?
select year_added, count(title) as titles,
    round(avg(year_added-release_year),1) as avg_gap,
    round(100.0 * count(case when (year_added-release_year) <=1 then 1 end) / count(*), 1) as new_pct
from netflix_clean
where "type" = 'Movie' and year_added >= 2015
group by year_added
order by year_added;
/*
"year_added","titles","avg_gap","new_pct"
2015,56,0.4,89.3
2016,253,2,75.5
2017,839,4.2,62.8
2018,1237,4.8,49
2019,1424,6.7,45.9
2020,1284,6,46
2021,993,7.7,40
*/

-- In 2015 most movies added to Netflix were new (89%).
-- In 2021 only 40% were new. Netflix adds more and more older movies.
-- But the data is from 2021, so some older movies added in early years
-- could already be removed from Netflix and are not in the data.


-- =====================================================
-- 3. Genres
-- =====================================================

-- Minimum number of votes: how many rated titles do we keep?
select  count(imdb_votes) as all_with_votes,
        count(case when imdb_votes >= 100 then 1 end) as more_than_100,
        count(case when imdb_votes >=1000 then 1 end) as more_than_1000
from netflix_clean
where imdb_rating is not NULL;
/*
"all_with_votes","more_than_100","more_than_1000"
7483,6942,5102
*/
-- With at least 100 votes we keep 6942 of 7483 rated titles (93%).
-- With 1000 votes we would lose almost a third, mostly smaller non-US titles.
-- So I use a minimum of 100 votes.

-- Average rating by genre (movies and TV shows together)
select g.genre, count(n.title) as titles, round(avg(n.imdb_rating),2) as avg_rating
from netflix_clean n 
join netflix_genres g on n.show_id=g.show_id
where n.imdb_votes >= 100
group by g.genre
having count(*)>=50
order by avg_rating desc;

-- TV show genres have higher ratings than movie genres
-- (e.g. Dramas 6.42 vs TV Dramas 7.32, Comedies 5.94 vs TV Comedies 7.09).
-- TV shows in general get higher ratings in IMDb, so genres should be compared separately for movies and TV shows.

-- Average rating by genre: movies only
select g.genre, count(n.title) as movies, round(avg(n.imdb_rating),2) as avg_rating
from netflix_clean n 
join netflix_genres g on n.show_id=g.show_id
where n.imdb_votes >= 100 and n."type" = 'Movie'
group by g.genre
having count(*)>=50
order by avg_rating desc;
/*
"genre","movies","avg_rating"
"Classic Movies",108,7.34
"Documentaries",645,6.93
"Cult Movies",65,6.84
"Stand-Up Comedy",268,6.81
"Sports Movies",181,6.58
"Dramas",2044,6.42
"Music & Musicals",286,6.41
"LGBTQ Movies",91,6.36
"Independent Movies",684,6.3
"International Movies",2106,6.22
"Romantic Movies",524,6.08
"Sci-Fi & Fantasy",217,6.01
"Action & Adventure",751,6
"Children & Family Movies",443,5.97
"Faith & Spirituality",51,5.96
"Comedies",1367,5.94
"Thrillers",518,5.9
"Horror Movies",314,5.33
*/
-- Best rated are Classic Movies (7.34), Documentaries (6.93) and Stand-Up Comedy (6.81).
-- Worst rated are Horror Movies (5.33), Thrillers and Comedies.

-- Average rating by genre: TV shows only
select g.genre, count(n.title) as TVshows, round(avg(n.imdb_rating),2) as avg_rating
from netflix_clean n 
join netflix_genres g on n.show_id=g.show_id
where n.imdb_votes >= 100 and n."type" = 'TV Show'
group by g.genre
having count(*)>=50
order by avg_rating desc;
/*
"genre","TVshows","avg_rating"
"Korean TV Shows",102,7.47
"Anime Series",138,7.39
"Science & Nature TV",71,7.37
"British TV Shows",193,7.33
"TV Dramas",569,7.32
"TV Action & Adventure",141,7.32
"Docuseries",295,7.32
"Crime TV Shows",394,7.27
"Romantic TV Shows",243,7.22
"Teen TV Shows",63,7.2
"TV Sci-Fi & Fantasy",71,7.2
"International TV Shows",950,7.19
"TV Comedies",446,7.09
"TV Mysteries",91,7.07
"Spanish-Language TV Shows",128,6.96
"TV Horror",63,6.9
"Reality TV",201,6.58
"Kids' TV",318,6.58
*/

-- Best rated are Korean TV Shows (7.47) and Anime Series (7.39),
-- worst are Reality TV and Kids' TV (6.58).


-- =====================================================
-- 4. Countries
-- =====================================================

-- Average rating by country: movies, TV shows and all titles
select c.country,count(n.title) as titles, 
        count(case when n."type"='Movie' then 1 end)as movies,
        round(avg(case when n."type" = 'Movie' then n.imdb_rating end),2) as movie_avg_rating,
        count(case when n."type"='TV Show' then 1 end)as tv_shows,
        round(avg(case when n."type" = 'TV Show' then n.imdb_rating end),2)as tv_show_avg_rating,
        round(avg(n.imdb_rating),2)as all_ratings
from netflix_clean n join netflix_countries c on n.show_id=c.show_id
where n.imdb_votes >= 100
group by c.country
having count(*) >= 20
order by all_ratings desc;
/*"country","titles","movies","movie_avg_rating","tv_shows","tv_show_avg_rating","all_ratings"
"South Korea",181,50,6.29,131,7.48,7.15
"Japan",250,85,6.49,165,7.36,7.07
"Ireland",43,30,6.66,13,7.72,6.98
"New Zealand",29,21,6.97,8,6.75,6.91
"Israel",27,18,6.57,9,7.56,6.9
"Pakistan",20,16,6.5,4,8.2,6.84
"Colombia",32,10,5.83,22,7.28,6.83
"United Kingdom",686,472,6.57,214,7.37,6.82
"Taiwan",55,19,6.38,36,7.05,6.82
"Denmark",40,28,6.66,12,7.14,6.81
"Lebanon",25,19,6.75,6,6.87,6.78
"Norway",24,18,6.53,6,7.5,6.77
"Sweden",35,29,6.61,6,7.48,6.76
"Russia",22,10,6.32,12,7.08,6.74
"Germany",199,161,6.5,38,7.15,6.63
"Australia",140,84,6.36,56,7.04,6.63
"France",355,276,6.44,79,6.87,6.54
"United States",3301,2484,6.27,817,7.08,6.47
"Spain",185,131,6.19,54,7.11,6.46
"Brazil",64,38,6.25,26,6.75,6.46
"Mexico",134,82,6.09,52,7.03,6.45
"Belgium",82,70,6.26,12,7.35,6.42
"Indonesia",74,71,6.39,3,7.03,6.41
"Thailand",45,33,6.09,12,7.25,6.4
"Netherlands",45,37,6.35,8,6.64,6.4
"Italy",84,64,6.27,20,6.74,6.38
"China",142,105,6.1,37,7.16,6.38
"Philippines",80,77,6.37,3,6.27,6.37
"Turkey",80,58,5.95,22,7.41,6.35
"Argentina",70,54,6.2,16,6.81,6.34
"Poland",37,29,6.17,8,6.9,6.33
"India",833,784,6.3,49,6.85,6.33
"Canada",381,272,6.08,109,6.86,6.3
"Hong Kong",89,88,6.28,1,7.2,6.29
"South Africa",46,39,6.22,7,6.54,6.27
"Czech Republic",21,15,6.42,6,5.55,6.17
"Chile",22,18,5.63,4,7.35,5.95
"Egypt",84,76,5.78,8,6.69,5.86
"Nigeria",49,46,5.58,3,6.87,5.66
"United Arab Emirates",26,25,5.57,1,6.2,5.59
*/
-- South Korea (7.15) and Japan (7.07) are at the top, mostly because of their TV shows and anime
-- (South Korea: 131 TV shows rated 7.48, but movies only 6.29).
-- Best rated movies come from New Zealand (6.97), Lebanon (6.75), Ireland and Denmark (6.66).
-- The United States is in the middle (6.47).
-- Poland is 31st of 40 countries (6.33): movies 6.17, TV shows 6.90.
-- Some countries have very few titles of one type (e.g. Pakistan: 4 TV shows), so those averages are not reliable.


-- =====================================================
-- 5. Movie duration
-- =====================================================

-- Are movies getting shorter? Average duration by decade of release
select 
    (release_year/10)*10 as decade,
    count(*) as movies,
    round(avg(duration_min),2) as avg_duration
from netflix_clean
where "type" = 'Movie'
group by decade
order by decade;
/*
"decade","movies","avg_duration"
1940,13,51.38
1950,11,107.09
1960,23,147.61
1970,66,119.24
1980,122,116.23
1990,241,113.84
2000,677,112.11
2010,4184,96.91
2020,794,93.64
*/
-- Movies are getting shorter: from 119 min (1970s) to 97 min (2010s) and 94 min (2020s).
-- The biggest drop is between the 2000s and the 2010s.
-- 1940s-1960s have very few movies (11-23), so those averages are not reliable
-- Part of the drop may come from more stand-ups, documentaries and kids' content,in recent years, not only from movies being shorter.


-- =====================================================
-- 6. TV show seasons
-- =====================================================

-- How many seasons do TV shows have, and are longer shows rated higher?
with shows as(
    select imdb_rating,imdb_votes,
        case when seasons>=5 then '5+'
            else cast(seasons as text)
        end as seasons_group
    from netflix_clean
    where "type" = 'TV Show'
)
select seasons_group, count(*) as tv_shows,
    round(100.0 * count(*) / sum(count(*)) over (), 1) as pct,
    round(avg(case when imdb_votes >= 100 then imdb_rating end), 2) as avg_rating
from shows
group by seasons_group
order by seasons_group;
/*
"seasons_group","tv_shows","pct","avg_rating"
"1",1793,67,7.03
"2",425,15.9,6.99
"3",199,7.4,7.39
"4",95,3.6,7.27
"5+",164,6.1,7.81
*/
-- 67% of TV shows on Netflix have only 1 season.
-- But the data is from 2021, so new shows had no time to get more seasons,
-- and some shows (mini-series, docuseries) are planned for one season only.
-- Shows with more seasons have higher ratings: about 7.0 for 1-2 seasons, 7.81 for 5+.
-- Probably good shows get more seasons, and weak shows are cancelled early.

-- Share of one-season TV shows by country
select
    c.country,
    count(*) as tv_shows,
    round(100.0 * count(case when n.seasons = 1 then 1 end) / count(*), 1) as one_season_pct
from netflix_clean n
join netflix_countries c on n.show_id = c.show_id
where n."type" = 'TV Show'
  and c.country in ('South Korea', 'Japan', 'United States', 'United Kingdom')
group by c.country
order by one_season_pct desc;
/*
"country","tv_shows","one_season_pct"
"South Korea",170,83.5
"Japan",199,64.8
"United Kingdom",272,60.3
"United States",938,53
*/
-- For example Korean dramas are usually planned as one season, so part of the 1-season shows
-- is just the format of the show, not a cancellation.
-- But even in the US more than half of the shows have only 1 season.
