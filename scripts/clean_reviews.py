"""
clean_reviews.py

올리스트(Olist) 리뷰 데이터셋(olist_order_reviews_dataset.csv)에는
review_comment_title / review_comment_message 컬럼 안에 실제 줄바꿈(개행)이
포함된 행이 다수 존재합니다.

MySQL의 LOAD DATA INFILE은 큰따옴표(ENCLOSED BY)로 감싸진 필드라 하더라도
LINES TERMINATED BY 기준으로 먼저 행을 나누기 때문에, 필드 안의 개행을
행 구분자로 잘못 인식해 이후 모든 행의 컬럼이 한 칸씩 밀리는 문제가 발생합니다.

이 스크립트는 pandas.read_csv로 따옴표를 올바르게 인식하며 원본을 읽어들인 뒤,
문제되는 컬럼의 개행을 공백으로 치환하고, 모든 필드를 큰따옴표로 감싸
(QUOTE_ALL) 다시 저장합니다. 이렇게 만든 CSV는 LOAD DATA INFILE로 안전하게
적재할 수 있습니다.

사용법:
    python clean_reviews.py

같은 폴더에 olist_order_reviews_dataset.csv 가 있어야 하며,
결과물로 olist_order_reviews_clean2.csv 가 생성됩니다.
"""

import csv
import pandas as pd

SRC = "olist_order_reviews_dataset.csv"
DST = "olist_order_reviews_clean2.csv"

# quotechar='"' 로 따옴표 안의 개행을 포함한 필드도 올바르게 하나의 셀로 인식
df = pd.read_csv(SRC, encoding="utf-8", quotechar='"')

print(f"읽은 행 개수: {len(df)}")

# 리뷰 제목/본문에 포함된 개행(\n, \r)을 공백으로 치환하여
# LOAD DATA INFILE의 행 구분(LINES TERMINATED BY '\n')과 충돌하지 않도록 함
for col in ["review_comment_title", "review_comment_message"]:
    df[col] = df[col].astype(str).str.replace(r"[\r\n]+", " ", regex=True)
    df[col] = df[col].replace("nan", "")

# 모든 필드를 큰따옴표로 감싸 저장 (MySQL ENCLOSED BY '"' 와 호환)
df.to_csv(
    DST,
    index=False,
    quoting=csv.QUOTE_ALL,
    encoding="utf-8",
    lineterminator="\n",
)

print(f"완료: {DST} 생성 (총 {len(df)}행)")
