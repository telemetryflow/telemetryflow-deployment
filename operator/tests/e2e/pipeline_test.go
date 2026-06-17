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
	"fmt"
	"os/exec"
	"testing"
	"time"

	"github.com/stretchr/testify/require"

	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/types"
	"k8s.io/client-go/kubernetes/scheme"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/envtest"

	telemetryflowv1alpha1 "github.com/telemetryflow/telemetryflow-operator/api/v1alpha1"
)

func init() {
	_ = telemetryflowv1alpha1.AddToScheme(scheme.Scheme)
	_ = appsv1.AddToScheme(scheme.Scheme)
	_ = corev1.AddToScheme(scheme.Scheme)
}

func TestOperatorPipeline(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping E2E test in short mode")
	}

	t.Run("should_reconcile_full_platform", func(t *testing.T) {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
		defer cancel()

		buildCmd := exec.Command("go", "build", "-o", "../../bin/manager", "../../main.go")
		err := buildCmd.Run()
		require.NoError(t, err, "Failed to build operator binary")

		testEnv := &envtest.Environment{
			CRDDirectoryPaths: []string{
				"../../config/crd/bases",
			},
		}
		cfg, err := testEnv.Start()
		require.NoError(t, err, "Failed to start envtest")
		defer func() { _ = testEnv.Stop() }()

		k8sClient, err := client.New(cfg, client.Options{Scheme: scheme.Scheme})
		require.NoError(t, err)

		const name = "e2e-pipeline"
		const namespace = "default"

		tf := &telemetryflowv1alpha1.TelemetryFlow{
			ObjectMeta: metav1.ObjectMeta{
				Name:      name,
				Namespace: namespace,
			},
			Spec: telemetryflowv1alpha1.TelemetryFlowSpec{
				Version: "1.4.0",
				PostgreSQL: telemetryflowv1alpha1.DatabaseSpec{
					Image:    "postgres:16-alpine",
					Replicas: 1,
				},
				Backend: telemetryflowv1alpha1.BackendSpec{
					Image:    "telemetryflow/backend:latest",
					Replicas: 1,
				},
				Agent: telemetryflowv1alpha1.AgentSpec{
					Enabled: true,
					Image:   "telemetryflow/agent:latest",
					Node: telemetryflowv1alpha1.AgentNodeSpec{
						Enabled: true,
					},
					Kubernetes: telemetryflowv1alpha1.AgentK8sSpec{
						Enabled:  true,
						Replicas: 1,
					},
				},
				Collector: telemetryflowv1alpha1.CollectorSpec{
					Image:    "telemetryflow/collector:latest",
					Replicas: 1,
				},
				Secrets: telemetryflowv1alpha1.SecretsSpec{
					Create: true,
				},
			},
		}

		err = k8sClient.Create(ctx, tf)
		require.NoError(t, err, "Failed to create TelemetryFlow CR")

		defer func() {
			tf := &telemetryflowv1alpha1.TelemetryFlow{}
			if err := k8sClient.Get(ctx, types.NamespacedName{Name: name, Namespace: namespace}, tf); err == nil {
				_ = k8sClient.Delete(ctx, tf)
			}
		}()

		const timeout = 60 * time.Second
		const interval = 500 * time.Millisecond

		t.Run("PostgreSQL_StatefulSet", func(t *testing.T) {
			require.Eventually(t, func() bool {
				return k8sClient.Get(ctx, types.NamespacedName{
					Name: fmt.Sprintf("%s-postgresql", name), Namespace: namespace,
				}, &appsv1.StatefulSet{}) == nil
			}, timeout, interval)
		})

		t.Run("Backend_Deployment", func(t *testing.T) {
			require.Eventually(t, func() bool {
				return k8sClient.Get(ctx, types.NamespacedName{
					Name: fmt.Sprintf("%s-backend", name), Namespace: namespace,
				}, &appsv1.Deployment{}) == nil
			}, timeout, interval)
		})

		t.Run("Agent_DaemonSet", func(t *testing.T) {
			require.Eventually(t, func() bool {
				return k8sClient.Get(ctx, types.NamespacedName{
					Name: fmt.Sprintf("%s-agent", name), Namespace: namespace,
				}, &appsv1.DaemonSet{}) == nil
			}, timeout, interval)
		})

		t.Run("Agent_K8s_Deployment", func(t *testing.T) {
			require.Eventually(t, func() bool {
				return k8sClient.Get(ctx, types.NamespacedName{
					Name: fmt.Sprintf("%s-agent-k8s", name), Namespace: namespace,
				}, &appsv1.Deployment{}) == nil
			}, timeout, interval)
		})

		t.Run("Collector_Deployment", func(t *testing.T) {
			require.Eventually(t, func() bool {
				return k8sClient.Get(ctx, types.NamespacedName{
					Name: fmt.Sprintf("%s-collector", name), Namespace: namespace,
				}, &appsv1.Deployment{}) == nil
			}, timeout, interval)
		})

		t.Run("Collector_ServiceAccount", func(t *testing.T) {
			require.Eventually(t, func() bool {
				return k8sClient.Get(ctx, types.NamespacedName{
					Name: fmt.Sprintf("%s-collector", name), Namespace: namespace,
				}, &corev1.ServiceAccount{}) == nil
			}, timeout, interval)
		})

		t.Run("Agent_ServiceAccount", func(t *testing.T) {
			require.Eventually(t, func() bool {
				return k8sClient.Get(ctx, types.NamespacedName{
					Name: fmt.Sprintf("%s-agent", name), Namespace: namespace,
				}, &corev1.ServiceAccount{}) == nil
			}, timeout, interval)
		})

		t.Run("Secrets", func(t *testing.T) {
			require.Eventually(t, func() bool {
				return k8sClient.Get(ctx, types.NamespacedName{
					Name: fmt.Sprintf("%s-secrets", name), Namespace: namespace,
				}, &corev1.Secret{}) == nil
			}, timeout, interval)
		})

		t.Run("Status_Ready", func(t *testing.T) {
			require.Eventually(t, func() bool {
				fetched := &telemetryflowv1alpha1.TelemetryFlow{}
				_ = k8sClient.Get(ctx, types.NamespacedName{Name: name, Namespace: namespace}, fetched)
				return fetched.Status.Phase == "Ready"
			}, timeout, interval)
		})

		t.Run("Deletion_Cleanup", func(t *testing.T) {
			tf := &telemetryflowv1alpha1.TelemetryFlow{}
			err := k8sClient.Get(ctx, types.NamespacedName{Name: name, Namespace: namespace}, tf)
			require.NoError(t, err)

			err = k8sClient.Delete(ctx, tf)
			require.NoError(t, err)

			require.Eventually(t, func() bool {
				return errors.IsNotFound(k8sClient.Get(ctx, types.NamespacedName{Name: name, Namespace: namespace}, &telemetryflowv1alpha1.TelemetryFlow{}))
			}, timeout, interval, "CR should be fully removed")
		})
	})
}
