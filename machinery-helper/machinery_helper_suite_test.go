package main_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"testing"
)

func TestMachineryHelper(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "MachineryHelper Suite")
}
