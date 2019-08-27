#!/bin/bash
set -xe

## Build fuzzing targets
## go-fuzz doesn't support modules for now, so ensure we do everything
## in the old style GOPATH way
export GO111MODULE="off"

## Install go-fuzz
go get -u github.com/dvyukov/go-fuzz/go-fuzz github.com/dvyukov/go-fuzz/go-fuzz-build

# download dependencies into ${GOPATH}
# -d : only download (don't install)f
# -v : verbose
# -u : use the latest version
# will be different if you use vendoring or a dependency manager
# like godep
go get -d -v -u ./...

go-fuzz-build -libfuzzer -o parse-complex.a .
clang -fsanitize=fuzzer parse-complex.a -o parse-complex

## Install fuzzit specific version for production or latest version for development :
# https://github.com/fuzzitdev/fuzzit/releases/latest/download/fuzzit_Linux_x86_64
wget -q -O fuzzit https://github.com/fuzzitdev/fuzzit/releases/download/v2.4.29/fuzzit_Linux_x86_64
chmod a+x fuzzit

if ${1} == "local-regression"; then
  LOCAL="--local"
  TYPE=regression
else
  LOCAL=""
  TYPE=fuzzing
fi

## upload fuzz target for long fuzz testing on fuzzit.dev server or run locally for regression
./fuzzit create job ${LOCAL} --type ${TYPE} fuzzitdev/parse-complex parse-complex
