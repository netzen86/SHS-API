ARG GOARCH=nonroot-amd64

# FROM debian

FROM gcr.io/distroless/static-debian12:${GOARCH}

WORKDIR /app

COPY --chown=nonroot:nonroot shs/opt /opt

COPY shs/bingo .

# RUN /app/bingo prepare_db

# EXPOSE 33207

# ENTRYPOINT ["/app/bingo", "prepare_db"] 

CMD ["/app/bingo", "run_server"]
# ENTRYPOINT ["tail"] 
# CMD ["-f","/dev/null"]