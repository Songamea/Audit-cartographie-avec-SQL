FROM apache/spark:3.5.1-python3
USER root
RUN pip install --no-cache-dir psycopg2-binary==2.9.9 prometheus-client==0.20.0
COPY spark_job.py /opt/spark/jobs/spark_job.py
