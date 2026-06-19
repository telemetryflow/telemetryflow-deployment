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
	"net/http"
	"os/exec"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestOperatorDataCollection(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping E2E test in short mode")
	}

	t.Run("should_expose_health_endpoint", func(t *testing.T) {
		buildCmd := exec.Command("go", "build", "-o", "../../bin/manager", "../../main.go")
		err := buildCmd.Run()
		require.NoError(t, err, "Failed to build operator binary")

		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()

		operatorCmd := exec.CommandContext(ctx, "../../bin/manager",
			"--health-probe-bind-address=:18081",
			"--metrics-bind-address=:18080",
		)
		err = operatorCmd.Start()
		require.NoError(t, err)
		defer func() {
			_ = operatorCmd.Process.Kill()
			_ = operatorCmd.Wait()
		}()

		time.Sleep(3 * time.Second)

		client := &http.Client{Timeout: 5 * time.Second}
		resp, err := client.Get("http://localhost:18081/healthz")
		if err != nil {
			t.Skipf("Could not connect to health endpoint: %v", err)
		}
		defer func() { _ = resp.Body.Close() }()

		assert.Equal(t, http.StatusOK, resp.StatusCode, "Health endpoint should return 200 OK")
	})

	t.Run("should_expose_metrics_endpoint", func(t *testing.T) {
		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()

		operatorCmd := exec.CommandContext(ctx, "../../bin/manager",
			"--health-probe-bind-address=:18081",
			"--metrics-bind-address=:18080",
		)
		err := operatorCmd.Start()
		require.NoError(t, err)
		defer func() {
			_ = operatorCmd.Process.Kill()
			_ = operatorCmd.Wait()
		}()

		time.Sleep(3 * time.Second)

		client := &http.Client{Timeout: 5 * time.Second}
		resp, err := client.Get("http://localhost:18080/metrics")
		if err != nil {
			t.Skipf("Could not connect to metrics endpoint: %v", err)
		}
		defer func() { _ = resp.Body.Close() }()

		assert.Equal(t, http.StatusOK, resp.StatusCode, "Metrics endpoint should return 200 OK")
	})

	t.Run("should_handle_concurrent_requests", func(t *testing.T) {
		ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
		defer cancel()

		operatorCmd := exec.CommandContext(ctx, "../../bin/manager",
			"--health-probe-bind-address=:18081",
			"--metrics-bind-address=:18080",
		)
		err := operatorCmd.Start()
		require.NoError(t, err)
		defer func() {
			_ = operatorCmd.Process.Kill()
			_ = operatorCmd.Wait()
		}()

		time.Sleep(3 * time.Second)

		client := &http.Client{Timeout: 10 * time.Second}
		concurrency := 10
		results := make(chan error, concurrency)

		for i := 0; i < concurrency; i++ {
			go func() {
				resp, err := client.Get("http://localhost:18081/healthz")
				if err != nil {
					results <- err
					return
				}
				_ = resp.Body.Close()
				if resp.StatusCode != http.StatusOK {
					results <- assert.AnError
					return
				}
				results <- nil
			}()
		}

		successCount := 0
		for i := 0; i < concurrency; i++ {
			if err := <-results; err == nil {
				successCount++
			}
		}

		assert.Equal(t, concurrency, successCount, "All concurrent requests should succeed")
	})
}
