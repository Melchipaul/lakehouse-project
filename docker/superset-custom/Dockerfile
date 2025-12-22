FROM apache/superset:latest

USER root

# Install database drivers (PostgreSQL + Dremio)
RUN /usr/local/bin/pip install --target=/app/.venv/lib/python3.10/site-packages \
    psycopg2-binary \
    sqlalchemy-dremio \
    pyarrow

USER superset
