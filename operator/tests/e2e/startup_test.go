// Package e2e_test contains end-to-end tests covering the full TelemetryFlow
// Operator lifecycle: startup, reconciliation pipeline, and graceful shutdown.
//
// TelemetryFlow Operator - AI-Powered Observability & Incident Response Management (IRM) Platform
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
	"os/exec"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestOperatorStartup(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping E2E test in short mode")
	}

	t.Run("should build operator binary", func(t *testing.T) {
		buildCmd := exec.Command("go", "build", "-o", "../../bin/manager", "../../main.go")
		err := buildCmd.Run()
		require.NoError(t, err, "Failed to build operator binary")
	})

	t.Run("should fail with missing kubeconfig", func(t *testing.T) {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		operatorCmd := exec.CommandContext(ctx, "../../bin/manager", "--kubeconfig=/nonexistent/kubeconfig")
		err := operatorCmd.Run()
		assert.Error(t, err, "Operator should fail with missing kubeconfig")
	})

	t.Run("should show help output", func(t *testing.T) {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		operatorCmd := exec.CommandContext(ctx, "../../bin/manager", "--help")
		output, err := operatorCmd.CombinedOutput()
		require.NoError(t, err, "Operator should show help without error")
		assert.Contains(t, string(output), "telemetryflow", "Help output should contain telemetryflow")
	})
}
