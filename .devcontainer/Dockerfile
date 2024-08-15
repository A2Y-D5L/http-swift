# Use the official Swift image as the base image
FROM swift:latest

# Install common utilities and dependencies for Swift development
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    vim \
    wget \
    build-essential \
    libssl-dev \
    libcurl4-openssl-dev \
    libsqlite3-dev \
    libpython3-dev \
    openssh-client \
    zip \
    unzip \
    less \
    ca-certificates \
    lsb-release \
    software-properties-common \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install swift-format
RUN git clone https://github.com/apple/swift-format.git /tmp/swift-format \
    && cd /tmp/swift-format \
    && swift build -c release \
    && cp -f .build/release/swift-format /usr/local/bin/ \
    && rm -rf /tmp/swift-format

# Install Docker
RUN curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh && rm get-docker.sh

# Set the working directory
WORKDIR /workspace

# Expose default port for server applications (e.g., Vapor)
EXPOSE 8080

# Set up a non-root user for running the container
ARG USERNAME=${GITHUB_ACTOR}
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME -s /bin/bash \
    && chown -R $USERNAME:$USERNAME /workspace

USER $USERNAME

# Fetch GitHub user's email and configure Git
RUN apt-get update && apt-get install -y jq curl \
    && GITHUB_EMAIL=$(curl -s https://api.github.com/users/$USERNAME | jq -r '.email') \
    && git config --global user.name "$USERNAME" \
    && git config --global user.email "$GITHUB_EMAIL"

# Default command to execute when the container starts
CMD [ "bash" ]