package utils

import (
	"fmt"
	"regexp"
	"strings"
)

func StringContains(s string, substrings ...string) bool {
	s = strings.ToLower(s)
	for _, substr := range substrings {
		if strings.Contains(s, strings.ToLower(substr)) {
			return true
		}
	}
	return false
}

func NormalizePhoneNumber(phoneNumber string) (string, error) {
	// Remove all non-digit characters first
	re := regexp.MustCompile(`\D+`)
	onlyDigits := re.ReplaceAllString(phoneNumber, "")

	// Check if the resulting string has at least 10 digits
	if len(onlyDigits) >= 10 {
		// Slice the string to get the last 10 characters
		return onlyDigits[len(onlyDigits)-10:], nil
	}

	// Return an empty string or an error if the string is too short
	return "", fmt.Errorf("invalid phone number")
}
