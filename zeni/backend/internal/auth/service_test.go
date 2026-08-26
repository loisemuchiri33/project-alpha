package auth

import "testing"

func TestNormalizePhone(t *testing.T) {
	cases := map[string]string{
		"0712345678":  "254712345678",
		"254712345678": "254712345678",
		"+254712345678": "254712345678",
		"712345678": "254712345678",
	}
	for in, want := range cases {
		got := normalizePhone(in)
		if got != want {
			t.Fatalf("normalizePhone(%q)=%q want %q", in, got, want)
		}
	}
}

func TestPasswordHashRoundTrip(t *testing.T) {
	hash, err := hashPassword("Str0ngPass!")
	if err != nil {
		t.Fatal(err)
	}
	if !verifyPassword(hash, "Str0ngPass!") {
		t.Fatal("expected password verify success")
	}
	if verifyPassword(hash, "wrong") {
		t.Fatal("expected password verify failure")
	}
}
