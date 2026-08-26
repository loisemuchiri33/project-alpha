package crypto

import "testing"

func TestEncryptDecrypt(t *testing.T) {
	key := "0123456789abcdef0123456789abcdef"
	ct, err := Encrypt("hello-zeni", key)
	if err != nil {
		t.Fatal(err)
	}
	pt, err := Decrypt(ct, key)
	if err != nil {
		t.Fatal(err)
	}
	if pt != "hello-zeni" {
		t.Fatalf("got %q", pt)
	}
}
