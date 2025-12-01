FROM python:3.12-slim-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir \
    Sphinx==8.1.3 \
    myst-parser==4.0.0 \
    sphinxcontrib-confluencebuilder==3.2.0

COPY sphinx_runbook/ /tmp/sphinx_runbook/sphinx_runbook/
COPY pyproject.toml /tmp/sphinx_runbook/pyproject.toml
RUN pip install --no-cache-dir /tmp/sphinx_runbook

ENV PLAYWRIGHT_BROWSERS_PATH=/usr/share/ms-playwright

RUN npm install -g playwright@1.47.0 \
    && playwright install chromium --with-deps \
    && chmod -R a+rX /usr/share/ms-playwright

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Run as root: GitHub runners mount the workspace owned by the runner uid and
# a non-root USER would not be able to write output/ (local runs pass -u).
WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
