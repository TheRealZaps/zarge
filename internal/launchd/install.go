package launchd

import (
	_ "embed"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"text/template"
)

const (
	label         = "local.zarge"
	plistPath     = "/Library/LaunchDaemons/local.zarge.plist"
	binaryInstall = "/usr/local/bin/zarge"
	logPath       = "/tmp/zarge.log"
)

//go:embed plist.tmpl
var plistTmpl string

type plistData struct {
	Label      string
	BinaryPath string
	LogPath    string
}

// Install copies the running binary to binaryInstall (if it isn't already
// there), writes the plist, and bootstraps the daemon.
func Install() error {
	if os.Geteuid() != 0 {
		return fmt.Errorf("install requires root (sudo)")
	}

	exe, err := os.Executable()
	if err != nil {
		return fmt.Errorf("locate executable: %w", err)
	}
	exe, err = filepath.EvalSymlinks(exe)
	if err != nil {
		return fmt.Errorf("resolve executable: %w", err)
	}

	if exe != binaryInstall {
		if err := copyFile(exe, binaryInstall, 0o755); err != nil {
			return fmt.Errorf("copy binary: %w", err)
		}
		fmt.Printf("installed binary at %s\n", binaryInstall)
	}

	if err := writePlist(binaryInstall); err != nil {
		return err
	}
	fmt.Printf("wrote plist at %s\n", plistPath)

	// Best-effort: unload any prior instance, then bootstrap.
	_ = exec.Command("launchctl", "bootout", "system", plistPath).Run()
	if out, err := exec.Command("launchctl", "bootstrap", "system", plistPath).CombinedOutput(); err != nil {
		return fmt.Errorf("launchctl bootstrap: %w: %s", err, out)
	}
	fmt.Println("loaded launchd job:", label)
	return nil
}

// Uninstall stops the daemon, removes the plist, and removes the installed binary.
func Uninstall() error {
	if os.Geteuid() != 0 {
		return fmt.Errorf("uninstall requires root (sudo)")
	}

	_ = exec.Command("launchctl", "bootout", "system", plistPath).Run()
	if err := os.Remove(plistPath); err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("remove plist: %w", err)
	}
	if err := os.Remove(binaryInstall); err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("remove binary: %w", err)
	}
	fmt.Println("uninstalled", label)
	return nil
}

// Purge stops the daemon, removes the plist and installed binary (same as
// Uninstall), and deletes the launchd StandardOutPath log file.
func Purge() error {
	if os.Geteuid() != 0 {
		return fmt.Errorf("purge requires root (sudo)")
	}
	if err := Uninstall(); err != nil {
		return err
	}
	if err := os.Remove(logPath); err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("remove log: %w", err)
	}
	fmt.Printf("removed log at %s\n", logPath)
	return nil
}

func writePlist(binaryPath string) error {
	t, err := template.New("plist").Parse(plistTmpl)
	if err != nil {
		return err
	}
	f, err := os.OpenFile(plistPath, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0o644)
	if err != nil {
		return err
	}
	defer f.Close()
	return t.Execute(f, plistData{Label: label, BinaryPath: binaryPath, LogPath: logPath})
}

func copyFile(src, dst string, mode os.FileMode) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return err
	}
	out, err := os.OpenFile(dst, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, mode)
	if err != nil {
		return err
	}
	defer out.Close()
	if _, err := io.Copy(out, in); err != nil {
		return err
	}
	return nil
}
