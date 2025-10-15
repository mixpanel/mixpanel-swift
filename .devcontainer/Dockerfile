# Swift Development Container for Mixpanel SDK
FROM swift:5.9-jammy

ARG TZ
ENV TZ="$TZ"

# Install essential development tools
RUN apt-get update && apt-get install -y \
  # Basic utilities
  less \
  git \
  procps \
  sudo \
  fzf \
  zsh \
  man-db \
  unzip \
  gnupg2 \
  curl \
  iptables \
  ipset \
  wget \
  aggregate \
  jq \
  ripgrep \
  tmux \
  # Build essentials
  build-essential \
  cmake \
  pkg-config \
  # Python for release scripts
  python3 \
  python3-pip \
  # Ruby for CocoaPods
  ruby-full \
  # Network tools for debugging
  dnsutils \
  iproute2 \
  # iOS development dependencies
  libssl-dev \
  libsqlite3-dev \
  && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
  && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
  && apt update \
  && apt install gh -y

# Install SwiftLint
RUN git clone --depth 1 --branch 0.54.0 https://github.com/realm/SwiftLint.git /tmp/SwiftLint \
  && cd /tmp/SwiftLint \
  && swift build -c release --product swiftlint \
  && cp .build/release/swiftlint /usr/local/bin/ \
  && rm -rf /tmp/SwiftLint

# Install swift-format
RUN git clone --depth 1 --branch 509.0.0 https://github.com/apple/swift-format.git /tmp/swift-format \
  && cd /tmp/swift-format \
  && swift build -c release --product swift-format \
  && cp .build/release/swift-format /usr/local/bin/ \
  && rm -rf /tmp/swift-format

# Install CocoaPods
RUN gem install cocoapods

# Create user for development
ARG USERNAME=developer
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
  && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
  && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME \
  && chmod 0440 /etc/sudoers.d/$USERNAME

# Persist bash history
RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
  && mkdir /commandhistory \
  && touch /commandhistory/.bash_history \
  && chown -R $USERNAME /commandhistory

# Set DEVCONTAINER environment variable
ENV DEVCONTAINER=true

# Create workspace and config directories
RUN mkdir -p /workspace /home/$USERNAME/.claude \
  && chown -R $USERNAME:$USERNAME /workspace /home/$USERNAME

WORKDIR /workspace

# Install delta for better git diffs
RUN ARCH=$(dpkg --print-architecture) && \
  wget "https://github.com/dandavison/delta/releases/download/0.18.2/git-delta_0.18.2_${ARCH}.deb" && \
  dpkg -i "git-delta_0.18.2_${ARCH}.deb" && \
  rm "git-delta_0.18.2_${ARCH}.deb"

# Install Claude Squad CLI
RUN curl -fsSL https://raw.githubusercontent.com/smtg-ai/claude-squad/main/install.sh | bash && \
  mv /root/.local/bin/cs /usr/local/bin/cs && \
  chmod +x /usr/local/bin/cs

# Copy scripts
COPY init-firewall.sh /usr/local/bin/
COPY setup-shell.sh /home/$USERNAME/.local/bin/

USER root
RUN chmod +x /usr/local/bin/init-firewall.sh && \
  mkdir -p /home/$USERNAME/.local/bin && \
  chmod +x /home/$USERNAME/.local/bin/setup-shell.sh && \
  chown $USERNAME:$USERNAME /home/$USERNAME/.local/bin/setup-shell.sh

# Switch to user
USER $USERNAME

# Set up zsh with Starship prompt
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended \
  && curl -sS https://starship.rs/install.sh | sh -s -- --yes

# Configure shell
RUN echo 'eval "$(starship init zsh)"' >> ~/.zshrc \
  && echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.zshrc \
  && echo 'alias swift-test="swift test --enable-code-coverage"' >> ~/.zshrc \
  && echo 'alias xcode-test="xcodebuild test -scheme MixpanelDemo -destination \"platform=iOS Simulator,name=iPhone 15\""' >> ~/.zshrc && \
  echo 'source /usr/share/doc/fzf/examples/key-bindings.zsh' >> ~/.zshrc && \
  echo 'source /usr/share/doc/fzf/examples/completion.zsh' >> ~/.zshrc

# Set default shell
ENV SHELL=/bin/zsh

# Install Node.js (for Claude Code)
USER root
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
  && apt-get install -y nodejs \
  && npm install -g @anthropic-ai/claude-code

USER $USERNAME

# Install global packages
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=$PATH:/usr/local/share/npm-global/bin

USER $USERNAME