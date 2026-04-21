package photogen

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func newTestProcessor(t *testing.T, photos []*Photo) *AlbumProcessor {
	t.Helper()
	cfg := &Config{
		OutputRoot: t.TempDir(),
		SiteID:     "test",
		Warn:       &WarnCollector{},
	}
	ac := &AlbumConfig{Slug: "test-album", Name: "Test Album"}
	ap := NewAlbumProcessor(cfg, ac)
	ap.Photos = photos
	return ap
}

func TestResizePhotos_Success(t *testing.T) {
	ap := newTestProcessor(t, []*Photo{
		{FileName: "landscape-1.jpg", AbsolutePath: filepath.Join("testdata", "landscape-1.jpg")},
	})

	err := ap.ResizePhotos()
	require.NoError(t, err)

	// Both size variants should have been written.
	for _, size := range AllSizes() {
		outPath := ap.OutputPath(string(size), WebPFileName("landscape-1.jpg"))
		_, statErr := os.Stat(outPath)
		assert.NoError(t, statErr, "expected output file for size %s", size)
	}
}

func TestResizePhotos_SkipExisting(t *testing.T) {
	ap := newTestProcessor(t, []*Photo{
		{FileName: "landscape-1.jpg", AbsolutePath: filepath.Join("testdata", "landscape-1.jpg")},
	})

	// First run writes files.
	require.NoError(t, ap.ResizePhotos())

	// Second run should skip without error.
	err := ap.ResizePhotos()
	require.NoError(t, err)
}

func TestResizePhotos_DryRun(t *testing.T) {
	ap := newTestProcessor(t, []*Photo{
		{FileName: "landscape-1.jpg", AbsolutePath: filepath.Join("testdata", "landscape-1.jpg")},
	})
	ap.Config.DryRun = true

	err := ap.ResizePhotos()
	require.NoError(t, err)

	// No files should have been written.
	for _, size := range AllSizes() {
		outPath := ap.OutputPath(string(size), WebPFileName("landscape-1.jpg"))
		_, statErr := os.Stat(outPath)
		assert.True(t, os.IsNotExist(statErr), "expected no output file for size %s in dry-run", size)
	}
}

func TestResizePhotos_ErrorOnBadInput(t *testing.T) {
	ap := newTestProcessor(t, []*Photo{
		{FileName: "missing.jpg", AbsolutePath: "/nonexistent/missing.jpg"},
	})

	err := ap.ResizePhotos()
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "resize")
}

func TestResizePhotos_Empty(t *testing.T) {
	ap := newTestProcessor(t, []*Photo{})
	err := ap.ResizePhotos()
	require.NoError(t, err)
}
