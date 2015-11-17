// Copyright (c) 2015 SUSE LLC
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of version 3 of the GNU General Public License as
// published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, contact SUSE LLC.
//
// To contact SUSE about this file by physical or electronic mail,
// you may find current contact information at www.suse.com

package mountpoints_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "github.com/SUSE/machinery/machinery-helper/mountpoints"
)

var _ = Describe("Mountpoints", func() {
	BeforeEach(func() {
		ProcMountsPath = "../fixtures/proc_mounts"
	})

	Describe("ParseMounts", func() {

		It("parses a map of mounts", func() {

			expectedMounts := map[string]string{
				"/dev":              "devtmpfs",
				"/homes/tux":        "nfs",
				"/data":             "ext4",
				"/":                 "ext4",
				"/var/lib/ntp/proc": "proc",
				"/var/lib/tmpfs":    "tmpfs",
			}

			Expect(ParseMounts()).To(Equal(expectedMounts))
		})
	})

	Describe("SpecialMounts", func() {
		It("parses a map of special mounts", func() {
			expectedMounts := []string{"/dev", "/var/lib/ntp/proc", "/var/lib/tmpfs"}
			Expect(SpecialMounts()).To(Equal(expectedMounts))
		})
	})

	Describe("LocalMounts", func() {
		It("parses a map of local mounts", func() {
			expectedMounts := []string{"/", "/data"}
			Expect(LocalMounts()).To(Equal(expectedMounts))
		})
	})

	Describe("RemouteMounts", func() {
		It("parses a map of remote mounts", func() {
			expectedMounts := []string{"/homes/tux"}
			Expect(RemoteMounts()).To(Equal(expectedMounts))
		})
	})
})
