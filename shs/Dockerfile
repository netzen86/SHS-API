# for mac change nonroot-arm64
ARG GOARCH=nonroot-amd64

FROM gcr.io/distroless/static-debian12:${GOARCH}

WORKDIR /app
# copy config file and direcroty struct in container
# COPY --chown=nonroot:nonroot opt/bongo /opt
# for local run uncomment next line
COPY --chown=nonroot:nonroot /opt /opt


COPY bingo .

CMD ["/app/bingo", "run_server"]
