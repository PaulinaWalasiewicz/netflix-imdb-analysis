[English](README.md) | **Polski**

# Netflix × IMDb: co sprawia, że treści na Netflixie są oceniane wysoko?

W tym projekcie połączyłam katalog Netflixa z ocenami z IMDb, żeby sprawdzić,
co Netflix dodaje do swojej biblioteki i jak te tytuły są oceniane.
Cała analiza jest zrobiona w **SQL (SQLite)**, a wykresy w **Pythonie (pandas, matplotlib)**.

![Filmy i seriale dodawane w kolejnych latach](images/01_movies_vs_tv.png)

## Dane

- **Netflix Movies and TV Shows** (Kaggle, Shivam Bansal): 8 807 tytułów dostępnych na Netflixie w 2021 roku
- **Zbiory danych IMDb** (title.basics, title.ratings): tytuły, lata, typy i oceny

Dane z Netflixa nie mają identyfikatora IMDb, więc największą częścią projektu było połączenie tych dwóch zbiorów.

## Jak połączyłam Netflixa z IMDb

Łączyłam tytuły po nazwie, roku i typie, a reguły poprawiałam krok po kroku:

| Krok | Połączone tytuły |
|---|---|
| Dokładne dopasowanie tytułu + roku + typu | 66,6% |
| Inne reguły roku dla filmów (maks. 2 lata różnicy) i seriali (dowolny wcześniejszy rok startu) | 77,4% |
| Ujednolicone tytuły (małe litery, bez znaków specjalnych) + oryginalne tytuły | **85,6%** |

Kilka problemów, na które trafiłam po drodze:
- Przy serialach Netflix podaje rok ostatniego sezonu, a IMDb rok, w którym serial się zaczął.
- Wiele tytułów ma taką samą nazwę jak inne filmy, więc musiałam wybrać właściwy.
  Najpierw brałam ten z dokładnie takim samym tytułem, a potem ten z największą liczbą głosów.
- Filmy krótkometrażowe z IMDb łączyły się z pełnometrażowymi filmami z Netflixa, więc dopuściłam je tylko dla krótkich filmów.

## Co odkryłam

**1. Od 2018 roku coraz więcej seriali.** Filmy zawsze są w większości, ale udział seriali
rośnie co roku od 2018 (z 25% do 33,7% w 2021).

**2. Netflix dodaje coraz więcej starszych filmów.** W 2015 roku 89% dodanych filmów było nowych.
W 2021 już tylko 40%.

![Nowe filmy](images/02_new_movies.png)

**3. Seriale mają wyższe oceny niż filmy.** Najlepiej oceniane gatunki filmów to Classic Movies,
Documentaries i Stand-Up Comedy. Najgorzej wypadają horrory. Wśród seriali na górze są Korean TV Shows i Anime.

![Gatunki](images/03_genres.png)

**4. Korea Południowa i Japonia mają najlepiej oceniane tytuły**, ale głównie dzięki serialom.
Polska jest na 31. miejscu na 40 krajów.

![Kraje](images/04_countries_b.png)

**5. Filmy są coraz krótsze:** od 119 minut w latach 70. do 94 minut w latach 20. XXI wieku.

![Długość filmów](images/05_duration.png)

**6. 67% seriali ma tylko 1 sezon**, ale seriale z większą liczbą sezonów są oceniane wyżej.
Koreańskie dramy są zwykle planowane jako jeden sezon, więc Korea ma najwięcej seriali z jednym sezonem (83,5%).

![Sezony](images/06_seasons.png)

## Ograniczenia

- Dane są z 2021 roku i pokazują tylko tytuły, które wtedy wciąż były na Netflixie.
- 14,4% tytułów z Netflixa nie udało się połączyć z IMDb.
- Przy ocenach brałam pod uwagę tylko tytuły z co najmniej 100 głosami, bo oceny z kilku głosów nie są wiarygodne.

## Struktura projektu

```
├── scripts/load_data.py         # wczytuje pliki CSV i IMDb do SQLite
├── sql/01_exploration.sql       # pierwsze spojrzenie na dane
├── sql/02_imdb_matching.sql     # łączenie Netflixa z IMDb
├── sql/03_cleaning.sql          # czyszczenie i końcowe tabele
├── sql/04_analysis.sql          # pytania analityczne
├── notebooks/analysis.ipynb     # wykresy
└── images/                      # wykresy użyte w tym README
```

## Jak uruchomić

1. Pobierz [zbiór danych Netflixa](https://www.kaggle.com/datasets/shivamb/netflix-shows)
   oraz pliki IMDb `title.basics.tsv.gz` i `title.ratings.tsv.gz` ze strony [IMDb datasets](https://datasets.imdbws.com/) do folderu `data/`
2. `pip install -r requirements.txt`
3. `python scripts/load_data.py`
4. Uruchom pliki SQL po kolei (01 → 04)
5. Otwórz `notebooks/analysis.ipynb`, żeby zobaczyć wykresy

Dane IMDb są używane w celach niekomercyjnych, zgodnie z warunkami IMDb.

## Narzędzia

SQL (SQLite), Python (pandas, matplotlib), Jupyter Notebook