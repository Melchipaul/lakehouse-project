# ========================================
# Stage 1: Builder - Compilation de Livy
# ========================================
FROM maven:3.9-eclipse-temurin-17 AS builder

# Variables de build
ARG LIVY_VERSION=master
ARG SPARK_PROFILE=spark-3.5

# Installer Git et Python (nécessaire pour python-api)
RUN apt-get update && \
    apt-get install -y git python3 python3-pip unzip && \
    ln -sf /usr/bin/python3 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip && \
    rm -rf /var/lib/apt/lists/*

# Cloner et compiler Livy pour Spark 3.5
WORKDIR /build
RUN git clone https://github.com/apache/incubator-livy.git && \
    cd incubator-livy && \
    git checkout ${LIVY_VERSION} && \
    mvn clean package -DskipTests -Dspark.version=3.5.4 -pl '!python-api,!integration-test,!coverage'

# Extraire l'artefact ZIP
RUN cd /build/incubator-livy/assembly/target && \
    unzip apache-livy-*-bin.zip && \
    mv apache-livy-*-bin /livy-build

# ========================================
# Stage 2: Runtime - Image finale légère
# ========================================
FROM apache/spark:3.5.4-python3

USER root

# Installer les dépendances runtime minimales
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Copier Livy depuis le stage de build
ENV LIVY_HOME=/opt/livy
COPY --from=builder /livy-build ${LIVY_HOME}

# Créer les répertoires nécessaires
RUN mkdir -p ${LIVY_HOME}/logs ${LIVY_HOME}/conf && \
    mkdir -p /home/spark/.ivy2 /home/spark/.cache && \
    chown -R 185:185 ${LIVY_HOME} /home/spark/.ivy2 /home/spark/.cache

# Copier les fichiers de configuration
COPY livy.conf ${LIVY_HOME}/conf/livy.conf
COPY log4j.properties ${LIVY_HOME}/conf/log4j.properties
COPY spark-defaults.conf.template ${LIVY_HOME}/conf/spark-defaults.conf.template
COPY entrypoint.sh ${LIVY_HOME}/entrypoint.sh

# Rendre le script exécutable
RUN chmod +x ${LIVY_HOME}/entrypoint.sh

# Variables d'environnement
ENV SPARK_HOME=/opt/spark
ENV PATH=${LIVY_HOME}/bin:${SPARK_HOME}/bin:$PATH

# Exposer le port Livy
EXPOSE 8998

WORKDIR ${LIVY_HOME}

# Utiliser le user Spark par défaut (185)
USER 185

# Entrypoint pour injecter les credentials
ENTRYPOINT ["./entrypoint.sh"]
