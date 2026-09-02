FROM spritsail/fivem:latest

COPY entrypoint.sh /usr/local/bin/sunset-entrypoint.sh
RUN chmod +x /usr/local/bin/sunset-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/sunset-entrypoint.sh"]
