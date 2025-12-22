FROM apache/zeppelin:0.12.0

USER root

# Copier les fichiers de configuration
COPY interpreter.json /tmp/interpreter.json
COPY spark-defaults.conf.template /tmp/spark-defaults.conf.template
COPY zeppelin-site.xml /opt/zeppelin/conf/zeppelin-site.xml
COPY entrypoint.sh /zeppelin/entrypoint.sh

# Rendre le script exécutable et donner les permissions
RUN chmod +x /zeppelin/entrypoint.sh && \
    chown -R 1000:1000 /zeppelin/entrypoint.sh /tmp/interpreter.json /tmp/spark-defaults.conf.template /opt/zeppelin/conf/zeppelin-site.xml

USER 1000

CMD ["/zeppelin/entrypoint.sh"]
