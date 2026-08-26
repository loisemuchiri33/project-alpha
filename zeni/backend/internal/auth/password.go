package auth

// HashPassword exposes argon2id hashing for staff creation by the CEO.
func HashPassword(password string) (string, error) {
	return hashPassword(password)
}
