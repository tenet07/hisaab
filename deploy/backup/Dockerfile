# Tiny image for the nightly backup: just the sqlite3 tool and Indian time.
FROM alpine:3.20
RUN apk add --no-cache sqlite tzdata
ENV TZ=Asia/Kolkata
COPY backup.sh /backup.sh
ENTRYPOINT ["/bin/sh", "/backup.sh"]
CMD ["loop"]
