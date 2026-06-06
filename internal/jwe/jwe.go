package jwe

import (
	"encoding/base64"
	"fmt"

	"github.com/go-jose/go-jose/v4"
)

func Encrypt(plaintext []byte, base64Key string) (string, error) {
	key, err := base64.StdEncoding.DecodeString(base64Key)
	if err != nil {
		return "", fmt.Errorf("decode jwe key: %w", err)
	}
	encrypter, err := jose.NewEncrypter(
		jose.A256GCM,
		jose.Recipient{Algorithm: jose.DIRECT, Key: key},
		nil,
	)
	if err != nil {
		return "", fmt.Errorf("new encrypter: %w", err)
	}
	obj, err := encrypter.Encrypt(plaintext)
	if err != nil {
		return "", fmt.Errorf("encrypt: %w", err)
	}
	return obj.CompactSerialize()
}

func Decrypt(token string, base64Key string) ([]byte, error) {
	key, err := base64.StdEncoding.DecodeString(base64Key)
	if err != nil {
		return nil, fmt.Errorf("decode jwe key: %w", err)
	}
	obj, err := jose.ParseEncrypted(
		token,
		[]jose.KeyAlgorithm{jose.DIRECT},
		[]jose.ContentEncryption{jose.A256GCM},
	)
	if err != nil {
		return nil, fmt.Errorf("parse encrypted: %w", err)
	}
	plaintext, err := obj.Decrypt(key)
	if err != nil {
		return nil, fmt.Errorf("decrypt: %w", err)
	}
	return plaintext, nil
}
