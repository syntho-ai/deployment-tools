# Stage 1: Base image to modify kubeconfig and building the dist
FROM python:3.12 as building-stage

### MODIFYING KUBECONFIG ###

RUN pip install pyyaml
WORKDIR /app
COPY modify_kubeconfig.py .
ARG KUBECONFIG
ARG CLUSTER_CONTAINER_NAME
ARG CLUSTER_INTERNAL_PORT
COPY ${KUBECONFIG} /root/.kube/config
RUN KUBECONFIG=/root/.kube/config CLUSTER_CONTAINER_NAME=${CLUSTER_CONTAINER_NAME} CLUSTER_INTERNAL_PORT=${CLUSTER_INTERNAL_PORT} python modify_kubeconfig.py

### MODIFYING KUBECONFIG ###


### BUILDING DIST ###

RUN curl -sSL https://install.python-poetry.org | python3 -
ENV PATH="/root/.local/bin:${PATH}"
COPY temp-workspace ./temp-workspace
WORKDIR /app/temp-workspace/cli
RUN poetry install --no-root
RUN poetry run poetry build
RUN poetry version | awk '{print $2}' > ./dist/.version

### BUILDING DIST ###

# Stage 2: Final stage
FROM python:3.12 as final-stage

COPY --from=building-stage /root/.kube/config /root/.kube/config
COPY --from=building-stage /app/temp-workspace/cli/dist /app/dist

RUN chmod 600 /root/.kube/config

# Install dependencies
RUN apt-get update && apt-get install -y iputils-ping vim

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && chmod +x kubectl \
    && mv kubectl /usr/local/bin/
ENV KUBECONFIG=/root/.kube/config

# Install jq
RUN curl -Lo /usr/local/bin/jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 \
    && chmod +x /usr/local/bin/jq

# Install yq
RUN curl -LO "https://github.com/mikefarah/yq/releases/download/v4.27.5/yq_linux_amd64" \
    && chmod +x yq_linux_amd64 \
    && mv yq_linux_amd64 /usr/local/bin/yq

# Install Helm
RUN curl -Lo /tmp/helm.tar.gz https://get.helm.sh/helm-v3.10.1-linux-amd64.tar.gz \
    && tar -zxvf /tmp/helm.tar.gz -C /tmp \
    && mv /tmp/linux-amd64/helm /usr/local/bin/helm \
    && chmod +x /usr/local/bin/helm \
    && rm -rf /tmp/helm.tar.gz /tmp/linux-amd64

# Install Docker CLI
RUN ARCH=$(uname -m) && curl -fsSL https://download.docker.com/linux/static/stable/$ARCH/docker-25.0.1.tgz | tar xzvf - --strip-components=1 -C /usr/local/bin docker/docker

# Install Docker Compose
RUN ARCH=$(uname -m) && \
    curl -L "https://github.com/docker/compose/releases/download/v2.16.0/docker-compose-linux-$ARCH" -o /usr/local/bin/docker-compose && \
    chmod +x /usr/local/bin/docker-compose

WORKDIR /app

RUN VERSION=$(cat /app/dist/.version) && \
    WHEEL="syntho_cli-${VERSION}.tar.gz" && \
    echo "WHEEL=${WHEEL}" > /tmp/wheel.env

# Install syntho-cli
RUN . /tmp/wheel.env && pip install /app/dist/${WHEEL}
