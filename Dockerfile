FROM debian:bookworm as builder

RUN apt update && \
    DEBIAN_FRONTEND=noninteractive apt install build-essential clang -y

ADD . /unishox2
WORKDIR /unishox2/mayhem-fuzz

RUN make

FROM debian:bookworm
COPY --from=builder /unishox2/mayhem-fuzz/unicode-fuzzer /