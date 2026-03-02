FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    NODE_VERSION=20

# Base deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates git jq bc && \
    rm -rf /var/lib/apt/lists/*

# Node.js (for Claude Code CLI)
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code

# Workspace
WORKDIR /workspace
COPY . /test-harness/

# The pm-workspace repo gets mounted at /workspace
# API key via env: ANTHROPIC_API_KEY

ENTRYPOINT ["bash", "/test-harness/harness.sh"]
CMD ["--mock"]
