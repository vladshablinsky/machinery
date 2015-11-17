package rpm_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"testing"
)

func TestRpm(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Rpm Suite")
}
