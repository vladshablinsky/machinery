package mountpoints_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"testing"
)

func TestMountpoints(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Mountpoints Suite")
}
