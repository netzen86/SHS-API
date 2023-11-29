# for mac change nonroot-arm64
ARG GOARCH=nonroot-amd64

# debian distroless
FROM gcr.io/distroless/static-debian12:${GOARCH}

WORKDIR /app

# for local run uncomment next line
# COPY --chown=nonroot:nonroot /opt /opt

COPY bingo .

# CMD ["/app/bingo", "prepare_db"]

CMD ["/app/bingo", "run_server"]
