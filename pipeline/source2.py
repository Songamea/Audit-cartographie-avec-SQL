import csv
import os
import shutil
import time
from pathlib import Path

from prometheus_client import Gauge, start_http_server

SOURCE = Path(os.getenv("SOURCE2_FILE", "/source-data/pc_captv_p.csv"))
TARGET = Path("/data-lake/raw/source2/pc_captv_p.csv")
ROWS = Gauge("source2_rows", "Rows copied from the Bordeaux sensor inventory")


def copy_source() -> None:
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(SOURCE, TARGET)
    with SOURCE.open(encoding="utf-8-sig", newline="") as handle:
        ROWS.set(sum(1 for _ in csv.DictReader(handle, delimiter=";")))
    print(f"source2 copied to {TARGET}", flush=True)


if __name__ == "__main__":
    start_http_server(9102)
    while True:
        try:
            copy_source()
        except Exception as exc:
            print(f"source2 error: {exc}", flush=True)
        time.sleep(60)
