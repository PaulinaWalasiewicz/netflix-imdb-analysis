import sqlite3
import csv
from pathlib import Path
import pandas as pd

# Paths 
ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data"
DB_PATH = ROOT / "netflix.db"

conn = sqlite3.connect(DB_PATH)

# Load Netflix data
print("Loading Netflix data...")
netflix_data = pd.read_csv(DATA / "netflix_titles.csv")
netflix_data.to_sql("netflix_raw", conn, if_exists="replace", index=False)

# Load IMDb titles data
print("Loading IMDb titles data...")
cols = ["tconst", "titleType", "primaryTitle", "originalTitle", "isAdult", "startYear", "endYear", "runtimeMinutes", "genres"]
chunks = pd.read_csv(DATA / "title.basics.tsv.gz", sep="\t", na_values="\\N", usecols=cols, dtype=str, quoting=csv.QUOTE_NONE, chunksize=500_000)

for i,chunk in enumerate(chunks):
    chunk.to_sql("imdb_titles_raw", conn, if_exists="replace" if i == 0 else "append", index=False)

# Load IMDb ratings data
print("Loading IMDb ratings data...")
ratings = pd.read_csv(DATA / "title.ratings.tsv.gz", sep="\t", na_values="\\N", quoting=csv.QUOTE_NONE)
ratings.to_sql("imdb_ratings_raw", conn, if_exists="replace", index=False)

conn.close()
print(f"Done! Database saved to {DB_PATH}")