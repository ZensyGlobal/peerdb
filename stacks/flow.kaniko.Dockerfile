FROM golang:1.26-alpine AS builder
ARG DEBUG_BUILD
ENV DEBUG_BUILD=${DEBUG_BUILD}
RUN apk add --no-cache gcc geos-dev musl-dev git curl
RUN curl -fsSL "https://github.com/bufbuild/buf/releases/download/v1.47.2/buf-Linux-aarch64" -o /usr/local/bin/buf && chmod +x /usr/local/bin/buf
WORKDIR /root
COPY . .
RUN rm -f go.work*
RUN buf generate protos --template buf.gen.flow.yaml
WORKDIR /root/flow
ENV CGO_ENABLED=1
RUN go mod download
RUN go generate
ENV GOCACHE=/root/.cache/go-build
RUN go build -o /root/peer-flow

FROM alpine:3.24 AS flow-base
ENV TZ=UTC
ADD https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem /usr/local/share/ca-certificates/global-aws-rds-bundle.pem
RUN apk add --no-cache ca-certificates geos && \
  update-ca-certificates && \
  adduser -s /bin/sh -D peerdb
USER peerdb
WORKDIR /home/peerdb
COPY --from=builder --chown=peerdb /root/peer-flow .
ENTRYPOINT [ "/home/peerdb/peer-flow" ]

FROM flow-base AS flow-api
ENTRYPOINT [ "/home/peerdb/peer-flow", "api", "--port", "8112", "--gateway-port", "8113"]

FROM flow-base AS flow-worker
ENTRYPOINT [ "/home/peerdb/peer-flow", "worker"]

FROM flow-base AS flow-snapshot-worker
ENTRYPOINT [ "/home/peerdb/peer-flow", "snapshot-worker"]

FROM flow-base AS flow-maintenance
ENTRYPOINT [ "/home/peerdb/peer-flow", "maintenance"]
