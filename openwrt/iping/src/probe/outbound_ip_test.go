package probe

import "testing"

func TestMentionsIpNeedsAWholeAddress(t *testing.T) {
	cases := map[string]bool{
		"fl=12f\nip=203.0.113.7\nts=1700000000.1": true,
		`{"ip":"2001:db8::7","country":"JP"}`:     true,
		`{"ip":"::ffff:203.0.113.7"}`:             true,
		`a::after{content:""}`:                    false,
		`div::before,li::marker{color:#fff}`:      false,
		`::-webkit-scrollbar{width:0}`:            false,
		`<a href="http://127.0.0.1/login">`:       false,
	}
	for body, want := range cases {
		if got := MentionsIP(body); got != want {
			t.Errorf("MentionsIP(%q) = %v, want %v", body, got, want)
		}
	}
}

func TestMentionsIpSkipsLocalAddresses(t *testing.T) {
	for _, body := range []string{
		"ip=192.168.1.1",
		`{"ip":"10.20.30.40"}`,
		"ip=172.16.0.9",
		"ip=100.64.12.34",
		`{"ip":"fd00::1"}`,
		`{"ip":"::ffff:192.168.1.1"}`,
	} {
		if MentionsIP(body) {
			t.Errorf("MentionsIP(%q) = true, want false", body)
		}
	}
}
