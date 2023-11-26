ARG GOARCH=nonroot-amd64

FROM gcr.io/distroless/static-debian12:${GOARCH}

WORKDIR /app

COPY --chown=nonroot:nonroot shs/opt /opt

COPY shs/bingo .

CMD ["/app/bingo", "run_server"]
