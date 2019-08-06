set -xe

## go-fuzz doesn't support modules for now, so ensure we do everything
## in the old style GOPATH way
export GO111MODULE="off"

if [ -z ${1+x} ]; then
    echo "must call with job type as first argument e.g. 'fuzzing' or 'sanity'"
    echo "see https://github.com/fuzzitdev/example-go/blob/master/.travis.yml"
    exit 1
fi

if [ -z "${FUZZIT_API_KEY}" ]; then
    echo "Please set env variable FUZZIT_API_KEY to api key for your project"
    exit 1
fi

## Install go-fuzz
go get -u github.com/dvyukov/go-fuzz/go-fuzz github.com/dvyukov/go-fuzz/go-fuzz-build

## build fuzzer
go build ./...
go-fuzz-build -libfuzzer -o fuzzer.a .
clang -fsanitize=fuzzer fuzzer.a -o fuzzer

wget -q -O fuzzit https://github.com/fuzzitdev/fuzzit/releases/download/v2.4.2/fuzzit_Linux_x86_64
chmod a+x fuzzit
./fuzzit auth ${FUZZIT_API_KEY}

if [ $1 == "fuzzing" ]; then
    ./fuzzit create job --branch $TRAVIS_BRANCH --revision $TRAVIS_COMMIT parse-complex ./fuzzer
else
    ./fuzzit create job --local parse-complex ./fuzzer
fi
