set -xe

## go-fuzz doesn't support modules for now, so ensure we do everything
## in the old style GOPATH way
export GO111MODULE="off"

if [ -z ${1+x} ]; then
    echo "must call with job type as first argument: 'fuzzing' or 'regression'"
    echo "see https://github.com/fuzzitdev/example-go/blob/master/.travis.yml"
    exit 1
fi

if [ -z "${FUZZIT_API_KEY}" ]; then
    echo "Please set env variable FUZZIT_API_KEY to api key for your project"
    echo "Api key for your account: https://app.fuzzit.dev/orgs/<ACCOUNT>/settings"
    exit 1
fi

## Install go-fuzz
go get -u github.com/dvyukov/go-fuzz/go-fuzz github.com/dvyukov/go-fuzz/go-fuzz-build

## build fuzz target

# target name can only contain lower-case letters (a-z), digits (0-9) and a dash (-)
TARGET=parse-complex

go-fuzz-build -libfuzzer -o ${TARGET}.a .
clang -fsanitize=fuzzer ${TARGET}.a -o ${TARGET}

# you can repeat the above for more fuzzing targets

## Install fuzzit cmd-line tool for talking to https://fuzzit.dev
wget -q -O fuzzit https://github.com/fuzzitdev/fuzzit/releases/download/v2.4.17/fuzzit_Linux_x86_64
chmod a+x fuzzit

# create fuzzing target on the server if it doesn't already exist
./fuzzit create target ${TARGET} || true

GIT_BRANCH=`git rev-parse --abbrev-ref HEAD`
GIT_COMMIT=`git rev-parse --short HEAD`

if [ $1 == "fuzzing" ]; then
    ./fuzzit create job --branch $GIT_BRANCH --revision $GIT_COMMIT ${TARGET} ./${TARGET}
else
    ./fuzzit create job --local ${TARGET} ./${TARGET}
fi
