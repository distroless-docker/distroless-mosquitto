package main

import (
	"bytes"
	"flag"
	"io"
	"log"
	"os"
	"os/exec"
	"os/user"
	"path/filepath"
	"syscall"
)

func ChownRecursively(path string, uid, gid int) error {
	return filepath.Walk(path, func(name string, info os.FileInfo, err error) error {
		if err == nil {
			err = os.Chown(name, uid, gid)
		}
		return err
	})
}

func main() {
	const defaultUserId = 1883
	const defaultGroupId = 1883
	const defaultDirToChown = "/mosquitto"

	dirToChown := flag.String("dirToChown", defaultDirToChown, "directory to change ownership for (defaults to /mosquitto)")
	userId := flag.Int("userId", defaultUserId, "numeric user-id (defaults to 1883)")
	groupId := flag.Int("groupId", defaultGroupId, "numeric group-id (defaults to 1883)")

	flag.Parse()

	additionalArgs := flag.Args()
	if len(additionalArgs) == 0 {
		log.Println("Usage: docker-scratch-entrypoint <cmd>")
		log.Println("See optional flags below which in case specified must occur before <cmd>")
		flag.PrintDefaults()
		os.Exit(1)
	}

	log.Println("Given user-id:  ", *userId)
	log.Println("Given group-id: ", *groupId)
	log.Println("Given path to chown: ", *dirToChown)

	//app, appArgs := strings.Join(additionalArgs[:1], " "), strings.Join(additionalArgs[1:], " ")
	app := additionalArgs[:1]
	appArgs := additionalArgs[1:]
	log.Println("App:  ", app)
	log.Println("Args: ", appArgs)

	user, err := user.Current()
	if err != nil {
		log.Fatalln(err)
	}

	// get current user-id
	log.Printf("Run as user: %v with id: %v\n", user.Username, user.Uid)

	_, err = os.Stat(*dirToChown)
	if err != nil {
		if os.IsNotExist(err) {
			log.Fatalf("Directory %v does not exist.\n", *dirToChown)
		}
	}

	// change ownership
	err = ChownRecursively(*dirToChown, *userId, *groupId)
	if err != nil {
		log.Println("Could not change ownership for ", *dirToChown)
		log.Println(err)
	}

	var cmd *exec.Cmd
	if len(appArgs) > 0 {
		log.Printf("going to run: %v with params %v", app, appArgs)
		cmd = exec.Command(app[0], additionalArgs[1:]...)
	} else {
		log.Printf("going to run: %v without params", app)
		cmd = exec.Command(app[0])
	}
	cmd.SysProcAttr = &syscall.SysProcAttr{}
	cmd.SysProcAttr.Credential = &syscall.Credential{Uid: uint32(*userId), Gid: uint32(*groupId)}

	var stdoutBuf, stderrBuf bytes.Buffer
	cmd.Stdout = io.MultiWriter(os.Stdout, &stdoutBuf)
	cmd.Stderr = io.MultiWriter(os.Stderr, &stderrBuf)

	// launch child app
	err = cmd.Start()
	if err != nil {
		log.Fatalln(err)
	}

	log.Println("Waiting for app ...")
	log.Println("PID: ", cmd.Process.Pid)

	// wait for child to finish
	err = cmd.Wait()
	if err != nil {
		log.Fatalf("Error returned by application: %v", err)
	}

	log.Println("Done.")
}
