#!/bin/bash
set -xe

# name of the organization in https://app.fuzzit.dev
export FUZZIT_ORG="example-go"

# target name can only contain lower-case letters (a-z), digits (0-9) and a dash (-)
TARGET=parse-complex

install_fuzzit () {
    # or latest version:
    # https://github.com/fuzzitdev/fuzzit/releases/latest/download/fuzzit_Linux_x86_64
    wget -q -O fuzzit https://github.com/fuzzitdev/fuzzit/releases/download/v2.4.17/fuzzit_Linux_x86_64
    chmod a+x fuzzit
}

build_fuzzing_targets () {
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

    go-fuzz-build -libfuzzer -o ${TARGET}.a .
    clang -fsanitize=fuzzer ${TARGET}.a -o ${TARGET}
}

check_api_key_set () {
    if [ -z "${FUZZIT_API_KEY}" ]; then
        echo "Please set env variable FUZZIT_API_KEY to api key for your project"
        echo "Api key for your account: https://app.fuzzit.dev/orgs/${FUZZIT_ORG}/settings"
        exit 1
    fi
}

build_and_upload_for_fuzzing () {
    check_api_key_set

    build_fuzzing_targets
    install_fuzzit

    # create fuzzing target on the server if it doesn't already exist
    ./fuzzit create target ${TARGET} || true

    GIT_BRANCH=`git rev-parse --abbrev-ref HEAD`
    GIT_COMMIT=`git rev-parse --short HEAD`

    # upload fuzz target for long fuzz testing on fuzzit.dev server
    ./fuzzit create job --branch $GIT_BRANCH --revision $GIT_COMMIT ${TARGET} ${TARGET}
}

build_and_run_regression_fuzzing () {
    build_fuzzing_targets
    install_fuzzit

    # run short, regression fuzzing job locally
    ./fuzzit create job --local ${FUZZIT_ORG}/${TARGET} ${TARGET}
}

if [ "fuzzing" == "${1}" ]; then
    build_and_upload_for_fuzzing
elif [ "regression" == "${1}" ]; then
    build_and_run_regression_fuzzing
else
    echo "call me with job type: 'fuzzing' or 'regression'"
    echo "see https://github.com/fuzzitdev/example-go/blob/master/.travis.yml"
    exit 1
fi
