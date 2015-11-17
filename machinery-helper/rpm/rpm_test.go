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

package rpm_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "github.com/SUSE/machinery/machinery-helper/rpm"
	"github.com/nowk/go-fakefileinfo"
	"os"
	"time"
)

var _ = Describe("Rpm", func() {

	Describe("ParseRpmLine", func() {
		var (
			gotType   string
			gotName   string
			gotTarget string
			line      string
		)

		JustBeforeEach(func() {
			gotType, gotName, gotTarget = ParseRpmLine(line)
		})

		Context("when parsing a file", func() {
			BeforeEach(func() {
				line = "-rw-r--r--    1 root    root                 18234080 Mar 31 11:40 /usr/lib64/libruby2.0-static.a"
			})

			It("returns name, type and link target", func() {
				expectedType := "-"
				expectedName := "/usr/lib64/libruby2.0-static.a"
				expectedTarget := ""

				Expect(gotType).To(Equal(expectedType))
				Expect(gotName).To(Equal(expectedName))
				Expect(gotTarget).To(Equal(expectedTarget))
			})
		})

		Context("when parsing a file with spaces", func() {
			BeforeEach(func() {
				line = "-rw-r--r--    1 root    root                    61749 Jun 26 01:56 /usr/share/kde4/templates/kipiplugins_photolayoutseditor/data/templates/a4/h/Flipping Tux Black.ple"
			})

			It("returns name, type and link target", func() {
				expectedType := "-"
				expectedName := "/usr/share/kde4/templates/kipiplugins_photolayoutseditor/data/templates/a4/h/Flipping Tux Black.ple"
				expectedTarget := ""

				Expect(gotType).To(Equal(expectedType))
				Expect(gotName).To(Equal(expectedName))
				Expect(gotTarget).To(Equal(expectedTarget))
			})
		})

		Context("when parsing a dir", func() {
			BeforeEach(func() {
				line = "drwxr-xr-x    2 root    root                        0 Mar 31 11:45 /usr/include/ruby-2.0.0/x86_64-linux/ruby"
			})

			It("returns name, type and link target", func() {
				expectedType := "d"
				expectedName := "/usr/include/ruby-2.0.0/x86_64-linux/ruby"
				expectedTarget := ""

				Expect(gotType).To(Equal(expectedType))
				Expect(gotName).To(Equal(expectedName))
				Expect(gotTarget).To(Equal(expectedTarget))
			})
		})

		Context("when parsing a link", func() {
			BeforeEach(func() {
				line = "lrwxrwxrwx    1 root    root                       19 Mar 31 11:45 /usr/lib64/libruby2.0.so -> libruby2.0.so.2.0.0"
			})

			It("returns name, type and link target", func() {
				expectedType := "l"
				expectedName := "/usr/lib64/libruby2.0.so"
				expectedTarget := "libruby2.0.so.2.0.0"

				Expect(gotType).To(Equal(expectedType))
				Expect(gotName).To(Equal(expectedName))
				Expect(gotTarget).To(Equal(expectedTarget))
			})
		})
	})

	Describe("AddImplicitlyManagedDirs", func() {
		var (
			dirsOriginal  map[string]bool
			filesOriginal map[string]string
			dirs          map[string]bool
		)

		JustBeforeEach(func() {
			AddImplicitlyManagedDirs(dirs, filesOriginal)
		})

		BeforeEach(func() {
			filesOriginal = map[string]string{
				"/abc/def/ghf/somefile": "",
				"/zzz":                  "/abc/def",
			}
			dirsOriginal = map[string]bool{
				"/abc/def": true,
			}
			dirs = dirsOriginal
		})

		It("updates the given dir with the implicit managed dirs", func() {
			dirsExpected := map[string]bool{
				"/abc":         false,
				"/abc/def":     true,
				"/abc/def/ghf": false,
				"/zzz":         false,
			}

			Expect(dirs).To(Equal(dirsExpected))
		})
	})

	Describe("AssembleJSON", func() {
		var (
			files_map map[string]string
			json      string
		)

		JustBeforeEach(func() {
			json = AssembleJSON(files_map)
		})

		Context("when parsing an unmanaged files map", func() {
			BeforeEach(func() {
				files_map = map[string]string{
					"name": "/usr/share/go_rulez", "type": "file",
				}

				It("returns a valid JSON", func() {
					want := `{
				 "extracted": false,
				 "files": {
					 "name": "/usr/share/go_rulez",
					 "type": "file"
				 }
			 }`
					Expect(json).To(Equal(want))
				})
			})
		})
	})

	Describe("HasManagedDirs", func() {
		Context("when a dir contains the given path", func() {
			path := "/managed_dir/unmanaged_dir"
			rpmDirs := map[string]bool{
				"/managed_dir":                                   true,
				"/managed_dir/unmanaged_dir/sub_dir/managed_dir": true,
			}

			It("returns true", func() {
				hasDirs := HasManagedDirs(path, rpmDirs)
				Expect(hasDirs).To(Equal(true))
			})
		})

		Context("when the given path matches partly", func() {
			path := "/usr/foo"
			rpmDirs := map[string]bool{
				"/usr":        true,
				"/usr/foobar": true,
			}

			It("returns false", func() {
				hasDirs := HasManagedDirs(path, rpmDirs)
				Expect(hasDirs).To(Equal(false))
			})
		})
	})

	Describe("FindUnmanagedFiles", func() {
		Context("when there are unmanaged dirs between managed dirs", func() {
			/*
			  We mock the readDir method and return following directory structure:
			   /
			   /managed_dir/
			   /managed_dir/unmanaged_dir/
			   /managed_dir/unmanaged_dir/managed_dir/
			*/

			var (
				readDir = func(dir string) ([]os.FileInfo, error) {
					dirs := make([]os.FileInfo, 0, 1)
					var fi os.FileInfo
					switch dir {
					case "/":
						fi = fakefileinfo.New("managed_dir", int64(123), os.ModeType, time.Now(), true, nil)
					case "/managed_dir/":
						fi = fakefileinfo.New("unmanaged_dir", int64(123), os.ModeType, time.Now(), true, nil)
					case "/managed_dir/unmanaged_dir/":
						fi = fakefileinfo.New("managed_dir", int64(123), os.ModeType, time.Now(), true, nil)
					}
					dirs = append(dirs, fi)
					return dirs, nil
				}
			)

			It("doesn't return the unmanaged dir", func() {
				unmanagedFiles := make(map[string]string)
				wantUnmanagedFiles := make(map[string]string)

				rpmFiles := make(map[string]string)
				ignoreList := make(map[string]bool)

				rpmDirs := map[string]bool{
					"/managed_dir":                           true,
					"/managed_dir/unmanaged_dir/managed_dir": true,
				}

				FindUnmanagedFiles(readDir, "/", rpmFiles, rpmDirs, unmanagedFiles, ignoreList)

				Expect(unmanagedFiles).To(Equal(wantUnmanagedFiles))
			})
		})
	})
})
