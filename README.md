[![Build Status](https://travis-ci.org/fuzzitdev/example-go.svg?branch=master)](https://travis-ci.org/fuzzitdev/example-go)
![fuzzit](https://app.fuzzit.dev/badge?org_id=hP8u8bNAda91Cnj0mKPX&branch=master)

# Continuous Fuzzing for Golang Example

This is an example of how to integrate your [go-fuzz](https://github.com/dvyukov/go-fuzz) targets with 
[Fuzzit](https://fuzzit.dev) Continuous Fuzzing Platform (Go support is currently in Alpha).

This example will show the following steps:
* [Building and running locally a simple go-fuzz target](#building-go-fuzz-target)
* [Integrate the go-fuzz target with Fuzzit via Travis-CI](#integrating-with-fuzzit-from-ci)

Result:
* Fuzzit will run the fuzz targets continuously on daily basis with the latest release.
* Fuzzit will run sanity tests on every pull-request with the generated corpus and crashes to catch bugs early on.

Fuzzing for go can both help find complex bugs as well as correctness bugs. Go is a safe language so memory corruption bugs
are very unlikely to happen but some bugs can still have security [implications](https://blog.cloudflare.com/dns-parser-meet-go-fuzzer/).

This tutorial is less about how to build go-fuzz targets but more about how to integrate the targets with Fuzzit. A lot of 
great information is available at the [go-fuzz](https://github.com/dvyukov/go-fuzz) repository.

## Building go-fuzz Target

The targets that are currently supported on Fuzzit is targets that utilize the libFuzzer engine. This is why we will
use the `-libfuzzer` flag of go-fuzz and compile it on Linux machine (should be also supported on mac in the future)

### Understanding the bug

The bug is located at `parser_complex.go` with the following code

```go
package parser

func ParseComplex(data [] byte) bool {
	if len(data) == 5 {
		if data[0] == 'F' && data[1] == 'U' && data[2] == 'Z' && data[3] == 'Z' && data[4] == 'I' && data[5] == 'T' {
			return true
		}
	}
	return false
}
```

This is the simplest example to demonstrate a classic off-by-one/out-of-bound error which causes the program to crash.
Instead of `len(data) == 5` the correct code will be `len(data) == 6`.

### Understanding the fuzzer

the fuzzer is located at `parse_complex_fuzz.go` with the following code:

```go
// +build gofuzz

package parser

func Fuzz(data []byte) int {
	ParseComplex(data)
	return 0
}
```

### Setting up the development environment

```bash
docker run -it golang:1.12.7-buster /bin/bash

# Download Clang-9
echo "deb http://apt.llvm.org/buster/ llvm-toolchain-buster main" >> /etc/apt/sources.list
echo "deb-src http://apt.llvm.org/buster/ llvm-toolchain-buster main" >> /etc/apt/sources.list
wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key| apt-key add -
apt update && apt install -y clang-9 lldb-9 lld-9

# Download go-fuzz and go-fuzz-build
go get -u github.com/dvyukov/go-fuzz/go-fuzz github.com/dvyukov/go-fuzz/go-fuzz-build

# Download this example
go get github.com/fuzzitdev/example-go
```

### Building the fuzzer

```bash
cd /go/src/github.com/fuzzitdev/example-go
go-fuzz-build -libfuzzer -o fuzzer.a .
clang-9 -fsanitize=fuzzer fuzzer.a -o fuzzer
```

### Running the fuzzer

```bash
./fuzzer
```

Will print the following output and stacktrace:

```text
INFO: Seed: 3709860458
INFO: 65536 Extra Counters
INFO: -max_len is not provided; libFuzzer will not generate inputs larger than 4096 bytes
INFO: A corpus is not provided, starting from an empty corpus
#2      INITED ft: 4 corp: 1/1b exec/s: 0 rss: 25Mb
#213    NEW    ft: 6 corp: 2/6b lim: 6 exec/s: 0 rss: 25Mb L: 5/5 MS: 1 CMP- DE: "\x01\x00\x00\x00"-
#13142  NEW    ft: 7 corp: 3/11b lim: 128 exec/s: 0 rss: 25Mb L: 5/5 MS: 4 EraseBytes-ChangeByte-ShuffleBytes-InsertByte-
#104833 NEW    ft: 8 corp: 4/16b lim: 1030 exec/s: 104833 rss: 25Mb L: 5/5 MS: 1 ChangeByte-
#262144 pulse  ft: 8 corp: 4/16b lim: 2589 exec/s: 87381 rss: 25Mb
#524288 pulse  ft: 8 corp: 4/16b lim: 4096 exec/s: 74898 rss: 25Mb
#1048576        pulse  ft: 8 corp: 4/16b lim: 4096 exec/s: 74898 rss: 25Mb
#1275694        NEW    ft: 9 corp: 5/21b lim: 4096 exec/s: 75040 rss: 25Mb L: 5/5 MS: 1 ChangeByte-
#1293550        NEW    ft: 10 corp: 6/26b lim: 4096 exec/s: 76091 rss: 25Mb L: 5/5 MS: 1 CopyPart-
panic: runtime error: index out of range

goroutine 17 [running, locked to thread]:
github.com/fuzzitdev/example-go/pkg/parser.ParseComplex.func5(...)
        /go/src/github.com/fuzzitdev/example-go/pkg/parser/parse_complex.go:5
github.com/fuzzitdev/example-go/pkg/parser.ParseComplex(0x2aabb20, 0x5, 0x5, 0xc00001e040)
        /go/src/github.com/fuzzitdev/example-go/pkg/parser/parse_complex.go:5 +0x1b2
github.com/fuzzitdev/example-go/pkg/parser.Fuzz(...)
        /go/src/github.com/fuzzitdev/example-go/pkg/parser/parse_complex_fuzz.go:6
main.LLVMFuzzerTestOneInput(0x2aabb20, 0x5, 0x545b78)
        /tmp/go-fuzz-build316206684/gopath/src/github.com/fuzzitdev/example-go/pkg/parser/go.fuzz.main/main.go:35 +0x84
main._cgoexpwrap_90699947e885_LLVMFuzzerTestOneInput(0x2aabb20, 0x5, 0x2aaab10)
        _cgo_gotypes.go:64 +0x37
==4262== ERROR: libFuzzer: deadly signal
    #0 0x45c110 in __sanitizer_print_stack_trace (/go/src/github.com/fuzzitdev/example-go/parser-fuzz.libfuzzer+0x45c110)
    #1 0x43b79b in fuzzer::PrintStackTrace() (/go/src/github.com/fuzzitdev/example-go/parser-fuzz.libfuzzer+0x43b79b)
    #2 0x422123 in fuzzer::Fuzzer::CrashCallback() (/go/src/github.com/fuzzitdev/example-go/parser-fuzz.libfuzzer+0x422123)
    #3 0x7f0ba60ff72f  (/lib/x86_64-linux-gnu/libpthread.so.0+0x1272f)
    #4 0x4acc70 in runtime.raise /tmp/go-fuzz-build316206684/goroot/src/runtime/sys_linux_amd64.s:149

NOTE: libFuzzer has rudimentary signal handlers.
      Combine libFuzzer with AddressSanitizer or similar for better crash reports.
SUMMARY: libFuzzer: deadly signal
MS: 1 ChangeByte-; base unit: 89b92cdd9bcb9b861c47c0179eff7b3a9baafcde
0x46,0x55,0x5a,0x5a,0x49,
FUZZI
artifact_prefix='./'; Test unit written to ./crash-df779ced6b712c5fca247e465de2de474d1d23b9
Base64: RlVaWkk=
```

## Integrating with Fuzzit from CI

The best way to integrate with Fuzzit is by adding a stage in your Contintous Build system
(like Travis CI or Circle CI). In that stage:
* build a fuzz target
* download `fuzzit` cli
* authenticate with `fuzzit auth`
* create a fuzzing job by uploading fuzz target

here is the relevant snippet from the [./ci/fuzzit.sh](https://github.com/fuzzitdev/example-go/blob/master/ci/fuzzit.sh)
which is being run by [.travis.yml](https://github.com/fuzzitdev/example-go/blob/master/.travis.yml)

```bash
wget -q -O fuzzit https://github.com/fuzzitdev/fuzzit/releases/download/v2.0.0/fuzzit_Linux_x86_64
chmod a+x fuzzit
./fuzzit auth ${FUZZIT_API_KEY}
export TARGET_ID=2n6hO2dQzylLxX5GGhRG
./fuzzit create job --type $1 --branch $TRAVIS_BRANCH --revision $TRAVIS_COMMIT $TARGET_ID ./fuzzer
``` 

NOTE: In production it is advised to download a pinned version of the [CLI](https://github.com/fuzzitdev/fuzzit)
like in the example. In development you can use latest version:
https://github.com/fuzzitdev/fuzzit/releases/latest/download/fuzzit_${OS}_${ARCH}.
Valid values for `${OS}` are: `Linux`, `Darwin`, `Windows`.
Valid values for `${ARCH}` are: `x86_64` and `i386`.

The steps are:
* Authenticate with the API key (you should keep this secret) you can find in the fuzzit settings dashboard.
* Upload the fuzzer via create job command and create the fuzzing job. In This example we use two type of jobs:
    * Fuzzing job which is run on every push to master which continuous the previous job just with the new release.
    Continuous means all the current corpus is kept and the fuzzer will try to find new paths in the newly added code
    * In a Pull-Request the fuzzer will run a quick "sanity" test running the fuzzer through all the generated corpus
    and crashes to see if the Pull-Request doesnt introduce old or new crashes. This will be alred via the configured
    channel in the dashboard
* The Target is not a secret. This ID can be retrieved from the dashboard after your create the appropriate target in the dashboard.
Each target has it's own corpus and crashes.
