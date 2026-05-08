package launchd

import (
	"os"
	"path/filepath"
	"testing"
)

func TestCopyFileCreatesParentDirectory(t *testing.T) {
	src := filepath.Join(t.TempDir(), "zarge")
	if err := os.WriteFile(src, []byte("binary"), 0o755); err != nil {
		t.Fatalf("write source: %v", err)
	}

	dst := filepath.Join(t.TempDir(), "usr", "local", "bin", "zarge")
	if err := copyFile(src, dst, 0o755); err != nil {
		t.Fatalf("copyFile returned error: %v", err)
	}

	got, err := os.ReadFile(dst)
	if err != nil {
		t.Fatalf("read destination: %v", err)
	}
	if string(got) != "binary" {
		t.Fatalf("destination content = %q, want %q", got, "binary")
	}
}
