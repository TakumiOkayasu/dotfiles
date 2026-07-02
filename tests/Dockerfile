FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    jq \
    grep \
    coreutils \
    git \
    bash \
    shellcheck \
    zsh \
    && rm -rf /var/lib/apt/lists/*

RUN git config --global user.email "test@test.com" && \
    git config --global user.name "Test" && \
    git config --global init.defaultBranch main

WORKDIR /workspace
COPY claude/hooks/ /workspace/hooks/
COPY common/hooks/ /workspace/hooks/
COPY bin/ /workspace/bin/
COPY tests/test_hooks.sh /workspace/test_hooks.sh
COPY tests/test_bin.sh /workspace/test_bin.sh

RUN chmod +x /workspace/hooks/*.sh /workspace/bin/* \
    /workspace/test_hooks.sh /workspace/test_bin.sh

ENTRYPOINT ["/workspace/test_hooks.sh"]
