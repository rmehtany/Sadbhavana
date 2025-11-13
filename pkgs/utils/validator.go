package utils

import (
	"github.com/go-playground/validator/v10"
)

var Validate = validator.New()

func ValidateStruct(s any) error {
	return Validate.Struct(s)
}
