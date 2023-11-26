ARG GOARCH=nonroot-amd64

FROM gcr.io/distroless/static-debian12:${GOARCH}

WORKDIR /app

COPY --chown=nonroot:nonroot /opt /opt

COPY bingo .

CMD ["/app/bingo", "run_server"]
