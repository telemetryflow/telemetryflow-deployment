// Package e2e_test contains end-to-end tests covering the full TelemetryFlow
// Operator lifecycle: startup, reconciliation pipeline, and graceful shutdown.
//
// TelemetryFlow Operator - Community Enterprise Observability Platform (CEOP)
// Copyright (c) 2024-2026 Telemetri Data Indonesia. All rights reserved.
// Open Source Software built by Telemetri Data Indonesia.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//	http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
package e2e_test

import (
	"context"
	"os"
	"os/exec"
	"syscall"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
)

func TestOperatorShutdown(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping E2E test in short mode")
	}

	t.Run("should handle SIGTERM gracefully", func(t *testing.T) {
		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()

		buildCmd := exec.CommandContext(ctx, "go", "build", "-o", "../../bin/manager", "../../main.go")
		err := buildCmd.Run()
		require.NoError(t, err, "Failed to build operator binary")

		operatorCmd := exec.Command("../../bin/manager", "--health-probe-bind-address=:0", "--metrics-bind-address=:0")
		err = operatorCmd.Start()
		require.NoError(t, err)

		time.Sleep(2 * time.Second)

		err = operatorCmd.Process.Signal(syscall.SIGTERM)
		require.NoError(t, err)

		done := make(chan error, 1)
		go func() {
			done <- operatorCmd.Wait()
		}()

		select {
		case <-done:
		case <-time.After(10 * time.Second):
			_ = operatorCmd.Process.Kill()
			t.Fatal("Operator did not shutdown within timeout")
		}
	})

	t.Run("should handle SIGINT gracefully", func(t *testing.T) {
		operatorCmd := exec.Command("../../bin/manager", "--health-probe-bind-address=:0", "--metrics-bind-address=:0")
		err := operatorCmd.Start()
		require.NoError(t, err)

		time.Sleep(2 * time.Second)

		err = operatorCmd.Process.Signal(os.Interrupt)
		require.NoError(t, err)

		done := make(chan error, 1)
		go func() {
			done <- operatorCmd.Wait()
		}()

		select {
		case <-done:
		case <-time.After(10 * time.Second):
			_ = operatorCmd.Process.Kill()
			t.Fatal("Operator did not shutdown within timeout")
		}
	})
}
