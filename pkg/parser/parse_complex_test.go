package parser

import "testing"

func TestParseComplex(t *testing.T) {
	res := ParseComplex([]byte("Incorrect Data"))
	if res {
		t.Fail()
	}
}
