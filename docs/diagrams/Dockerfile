# syntax=docker/dockerfile:1
# The tools of bin/diagrams: Graphviz and the Python library diagrams, which
# draws architecture diagrams as code with the AWS Architecture Icons it ships.
# requirements.txt pins diagrams and its dependencies with hashes (bin/diagrams
# --lock writes it from requirements.in).
FROM python:3.13-slim@sha256:e48f59cdba69a3cbd9ed2cf0f348d90d45a8d350d98134cf1070bc106ee9ed90
RUN apt-get update && apt-get install -y --no-install-recommends graphviz fonts-noto-cjk \
  && rm -rf /var/lib/apt/lists/*
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir --require-hashes -r /tmp/requirements.txt && rm /tmp/requirements.txt
WORKDIR /work/docs/diagrams
