set -xe

## Install go-fuzz
go get -u github.com/dvyukov/go-fuzz/go-fuzz github.com/dvyukov/go-fuzz/go-fuzz-build

## build fuzzer
go build ./...
go-fuzz-build -libfuzzer -o fuzzer.a ./...
clang -fsanitize=fuzzer fuzzer.a -o fuzzer

wget -q -O fuzzit https://github.com/fuzzitdev/fuzzit/releases/download/v2.4.1/fuzzit_Linux_x86_64
chmod a+x fuzzit
./fuzzit auth ${FUZZIT_API_KEY}

if [ $1 == "fuzzing" ]; then
    ./fuzzit create job --branch $TRAVIS_BRANCH --revision $TRAVIS_COMMIT parse-complex ./fuzzer
else
    ./fuzzit create job --local parse-complex ./fuzzer
end
