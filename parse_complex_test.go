package parser

// This is just an example of a generational fuzzer which benchmarks the resutls against a coverage guided fuzzer
// This won't find the results for never probabbly ...

import (
	"github.com/google/gofuzz"
	"testing"
)

func TestParseComplex(t *testing.T) {
	f := fuzz.New()
	var inputString string
	for true {
		f.Fuzz(&inputString)
		ParseComplex([]byte(inputString))
	}
}
