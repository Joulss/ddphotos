package exit

import (
	"errors"
	"fmt"
	"os"
	"os/signal"
	"runtime/debug"
	"sync"
	"sync/atomic"
)

var (
	exitRequested   int32
	exitError       error
	cleanupCalled   bool
	cleanupLock     sync.Mutex
	cleanupCallback func()
)

// ExitRequested returns true if exit has been requested.
//
//goland:noinspection GoNameStartsWithPackageName
func ExitRequested() bool {
	return atomic.LoadInt32(&exitRequested) == 1
}

// SetExitRequested requests a graceful exit.
func SetExitRequested() {
	atomic.StoreInt32(&exitRequested, 1)
}

// SetExitRequestedWithError requests a graceful exit and records err,
// which causes a non-zero exit status.
func SetExitRequestedWithError(err error) {
	SetExitRequested()
	cleanupLock.Lock()
	defer cleanupLock.Unlock()
	exitError = err
}

// SetCleanupCallback registers a function to call when a signal is received or a panic is handled.
func SetCleanupCallback(cb func()) {
	cleanupCallback = cb
}

// Fatal prints an error message and exits with a non-zero status.
// If err is non-nil, it prints "msg: err"; otherwise it prints msg.
func Fatal(msg string, err error) {
	if err != nil {
		fmt.Printf("%s: %s\n", msg, err)
	} else {
		fmt.Println(msg)
		err = errors.New(msg)
	}
	ExitWithStatus(err)
}

// ExitWithStatus exits with status 0 if err is nil and no prior error was recorded, otherwise 1.
//
//goland:noinspection GoNameStartsWithPackageName
func ExitWithStatus(err error) {
	cleanupLock.Lock()
	defer cleanupLock.Unlock()
	code := 0
	if err != nil || exitError != nil {
		code = 1
	}
	os.Exit(code)
}

// CatchPanic recovers from a panic, prints the error and stack trace, and triggers
// a graceful exit (calling the cleanup callback if set). Note that any values returned
// from the enclosing function are reset to their zero values (e.g., bool is false,
// error is nil). A function that returns true to continue works well with this:
//
//	func process() bool {
//	   defer CatchPanic()
//	   ...
//	}
//
// This will automatically return false on panic.
func CatchPanic() {
	if r := recover(); r != nil {
		fmt.Printf("PANIC %v\n%s", r, string(debug.Stack()))
		exitTriggered(fmt.Errorf("panic: %v", r))
	}
}

// CatchPanicError recovers from a panic, prints the error and stack trace, and stores
// the panic value in the provided error pointer. The common use case is a named return
// variable:
//
//	func broken() (err error) {
//	   defer exit.CatchPanicError(&err)
//	   ...
//	}
func CatchPanicError(err *error) {
	if r := recover(); r != nil {
		fmt.Printf("PANIC %v\n%s", r, string(debug.Stack()))
		*err = fmt.Errorf("panic: %v", r)
	}
}

// PanicOnError panics if err is non-nil.
func PanicOnError(err error) {
	if err != nil {
		panic(err)
	}
}

// HandleSignal listens for CTRL-C (SIGINT) and triggers a graceful exit,
// calling the cleanup callback if one is set.
func HandleSignal() {
	signals := make(chan os.Signal, 1)
	// NOTE: was catching syscall.SIGPIPE to allow use of 'tee',
	//       but was getting spurious errors, so removed it.
	signal.Notify(signals, os.Interrupt)

	go func() {
		sig := <-signals
		fmt.Printf("\n\n*** Signal '%s' detected, exiting... ***\n\n", sig)
		exitTriggered(nil)
	}()
}

// ClearExitRequested clears the exit-requested flag (useful in unit tests).
func ClearExitRequested() {
	atomic.StoreInt32(&exitRequested, 0)
}

func exitTriggered(err error) {
	cleanupLock.Lock()
	defer cleanupLock.Unlock()
	SetExitRequested()
	exitError = err
	if cleanupCallback != nil && !cleanupCalled {
		cleanupCallback()
		cleanupCalled = true
	}
}
