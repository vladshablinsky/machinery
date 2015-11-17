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

package main

import (
	"flag"
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"sort"

	"github.com/SUSE/machinery/machinery-helper/mountpoints"
	"github.com/SUSE/machinery/machinery-helper/rpm"
)

func printVersion() {
	fmt.Println("Version:", VERSION)
	os.Exit(0)
}

func main() {
	// check for tar extraction
	if len(os.Args) >= 2 {
		switch os.Args[1] {
		case "tar":
			Tar(os.Args[2:])
			os.Exit(0)
		}
	}

	// parse CLI arguments
	var versionFlag = flag.Bool("version", false, "shows the version number")
	flag.Parse()

	// show version
	if *versionFlag == true {
		printVersion()
	}

	// fetch unmanaged files
	unmanagedFiles := make(map[string]string)
	thisBinary, _ := filepath.Abs(os.Args[0])

	ignoreList := map[string]bool{
		thisBinary: true,
	}
	for _, mount := range mountpoints.RemoteMounts() {
		ignoreList[mount] = true
	}
	for _, mount := range mountpoints.SpecialMounts() {
		ignoreList[mount] = true
	}

	for _, mount := range mountpoints.RemoteMounts() {
		unmanagedFiles[mount+"/"] = "remote_dir"
	}

	var readDir = func(dir string) ([]os.FileInfo, error) {
		return ioutil.ReadDir(dir)
	}

	rpmFiles, rpmDirs := rpm.GetManagedFiles()
	rpm.FindUnmanagedFiles(readDir, "/", rpmFiles, rpmDirs, unmanagedFiles, ignoreList)

	files := make([]string, len(unmanagedFiles))
	i := 0
	for k := range unmanagedFiles {
		files[i] = k
		i++
	}
	sort.Strings(files)

	unmanagedFilesMap := make([]map[string]string, len(unmanagedFiles))
	for j := range files {
		entry := make(map[string]string)
		entry["name"] = files[j]
		entry["type"] = unmanagedFiles[files[j]]
		unmanagedFilesMap[j] = entry
	}

	json := rpm.AssembleJSON(unmanagedFilesMap)
	fmt.Println(json)
}
