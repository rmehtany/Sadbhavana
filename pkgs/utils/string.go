package utils

import "strings"

func StringContains(s string, substrings ...string) bool {
	s = strings.ToLower(s)
	for _, substr := range substrings {
		if strings.Contains(s, strings.ToLower(substr)) {
			return true
		}
	}
	return false
}
