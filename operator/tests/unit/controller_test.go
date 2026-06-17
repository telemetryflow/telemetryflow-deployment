// Package controller_test contains unit tests for the TelemetryFlow controller
// reconciliation logic using envtest (etcd + kube-apiserver, no real cluster needed).
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
package controller_test

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	rbacv1 "k8s.io/api/rbac/v1"
	"k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/types"
	"k8s.io/client-go/kubernetes/scheme"
	"k8s.io/client-go/rest"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/envtest"
	logf "sigs.k8s.io/controller-runtime/pkg/log"
	"sigs.k8s.io/controller-runtime/pkg/log/zap"

	telemetryflowv1alpha1 "github.com/telemetryflow/telemetryflow-operator/api/v1alpha1"
	"github.com/telemetryflow/telemetryflow-operator/internal/controller"
)

var (
	cfg       *rest.Config
	k8sClient client.Client
	testEnv   *envtest.Environment
	ctx       context.Context
	cancel    context.CancelFunc
)

func init() {
	_ = telemetryflowv1alpha1.AddToScheme(scheme.Scheme)
	_ = appsv1.AddToScheme(scheme.Scheme)
	_ = corev1.AddToScheme(scheme.Scheme)
	_ = rbacv1.AddToScheme(scheme.Scheme)
}

func TestMain(m *testing.M) {
	logf.SetLogger(zap.New(zap.WriteTo(os.Stdout), zap.UseDevMode(true)))

	ctx, cancel = context.WithCancel(context.TODO())

	testEnv = &envtest.Environment{
		CRDDirectoryPaths: []string{
			filepath.Join("..", "..", "config", "crd", "bases"),
		},
		ErrorIfCRDPathMissing: true,
		BinaryAssetsDirectory: filepath.Join("..", "..", "bin", "k8s",
			fmt.Sprintf("1.32.0-%s-%s", runtime.GOOS, runtime.GOARCH)),
	}

	var err error
	cfg, err = testEnv.Start()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to start envtest: %v\n", err)
		os.Exit(1)
	}

	k8sClient, err = client.New(cfg, client.Options{Scheme: scheme.Scheme})
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to create k8s client: %v\n", err)
		os.Exit(1)
	}

	k8sManager, err := ctrl.NewManager(cfg, ctrl.Options{Scheme: scheme.Scheme})
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to create manager: %v\n", err)
		os.Exit(1)
	}

	err = (&controller.TelemetryFlowReconciler{
		Client: k8sManager.GetClient(),
		Scheme: k8sManager.GetScheme(),
	}).SetupWithManager(k8sManager)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to setup controller: %v\n", err)
		os.Exit(1)
	}

	go func() {
		if err := k8sManager.Start(ctx); err != nil {
			fmt.Fprintf(os.Stderr, "Failed to start manager: %v\n", err)
			os.Exit(1)
		}
	}()

	code := m.Run()

	cancel()
	if err := testEnv.Stop(); err != nil {
		fmt.Fprintf(os.Stderr, "Failed to stop envtest: %v\n", err)
		os.Exit(1)
	}

	os.Exit(code)
}

const (
	timeout  = 60 * time.Second
	interval = 250 * time.Millisecond
)

func TestReconcileAllComponents(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping unit test in short mode")
	}

	const (
		namespace = "default"
		name      = "test-telemetryflow"
	)

	t.Run("should create TelemetryFlow and reconcile all 14 components", func(t *testing.T) {
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
					Resources: &telemetryflowv1alpha1.ResourceSpec{
						Requests: telemetryflowv1alpha1.CoreResource{CPU: "100m", Memory: "128Mi"},
						Limits:   telemetryflowv1alpha1.CoreResource{CPU: "500m", Memory: "512Mi"},
					},
					Persistence: &telemetryflowv1alpha1.PersistenceSpec{
						Enabled: true,
						Size:    "1Gi",
					},
				},
				ClickHouse: telemetryflowv1alpha1.DatabaseSpec{
					Image:    "clickhouse/clickhouse-server:24-alpine",
					Replicas: 1,
				},
				Redis: telemetryflowv1alpha1.RedisSpec{
					Image: "redis:7-alpine",
				},
				BullMQRedis: telemetryflowv1alpha1.RedisSpec{
					Image: "redis:7-alpine",
				},
				NATS: telemetryflowv1alpha1.NATSSpec{
					Image:            "nats:2-alpine",
					JetStreamEnabled: true,
				},
				Collector: telemetryflowv1alpha1.CollectorSpec{
					Image:    "telemetryflow/collector:latest",
					Replicas: 1,
					ServiceAccount: telemetryflowv1alpha1.ServiceAccountSpec{
						Create: true,
					},
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
					ServiceAccount: telemetryflowv1alpha1.ServiceAccountSpec{
						Create: true,
					},
				},
				Backend: telemetryflowv1alpha1.BackendSpec{
					Image:    "telemetryflow/backend:latest",
					Replicas: 1,
				},
				Frontend: telemetryflowv1alpha1.FrontendSpec{
					Image:    "telemetryflow/frontend:latest",
					Replicas: 1,
				},
				Secrets: telemetryflowv1alpha1.SecretsSpec{
					Create: true,
				},
			},
		}

		err := k8sClient.Create(ctx, tf)
		require.NoError(t, err, "Failed to create TelemetryFlow CR")

		t.Cleanup(func() {
			tf := &telemetryflowv1alpha1.TelemetryFlow{}
			if err := k8sClient.Get(ctx, types.NamespacedName{Name: name, Namespace: namespace}, tf); err == nil {
				_ = k8sClient.Delete(ctx, tf)
			}
		})

		t.Run("StatefulSets_created", func(t *testing.T) {
			statefulSets := []string{"postgresql", "clickhouse", "redis", "bullmq-redis", "nats"}
			for _, component := range statefulSets {
				t.Run(component, func(t *testing.T) {
					key := types.NamespacedName{
						Name:      fmt.Sprintf("%s-%s", name, component),
						Namespace: namespace,
					}
					require.Eventually(t, func() bool {
						return k8sClient.Get(ctx, key, &appsv1.StatefulSet{}) == nil
					}, timeout, interval, "StatefulSet %s should be created", component)
				})
			}
		})

		t.Run("Deployments_created", func(t *testing.T) {
			deployments := []string{"collector", "agent-k8s", "backend", "frontend"}
			for _, component := range deployments {
				t.Run(component, func(t *testing.T) {
					key := types.NamespacedName{
						Name:      fmt.Sprintf("%s-%s", name, component),
						Namespace: namespace,
					}
					require.Eventually(t, func() bool {
						return k8sClient.Get(ctx, key, &appsv1.Deployment{}) == nil
					}, timeout, interval, "Deployment %s should be created", component)
				})
			}
		})

		t.Run("Agent_DaemonSet_created", func(t *testing.T) {
			key := types.NamespacedName{
				Name:      fmt.Sprintf("%s-agent", name),
				Namespace: namespace,
			}
			require.Eventually(t, func() bool {
				return k8sClient.Get(ctx, key, &appsv1.DaemonSet{}) == nil
			}, timeout, interval, "Agent DaemonSet should be created")
		})

		t.Run("Services_created", func(t *testing.T) {
			services := []string{"redis", "bullmq-redis", "nats", "collector", "backend", "frontend"}
			for _, svc := range services {
				t.Run(svc, func(t *testing.T) {
					key := types.NamespacedName{
						Name:      fmt.Sprintf("%s-%s", name, svc),
						Namespace: namespace,
					}
					require.Eventually(t, func() bool {
						return k8sClient.Get(ctx, key, &corev1.Service{}) == nil
					}, timeout, interval, "Service %s should be created", svc)
				})
			}
		})

		t.Run("Collector_RBAC_created", func(t *testing.T) {
			t.Run("ServiceAccount", func(t *testing.T) {
				key := types.NamespacedName{
					Name:      fmt.Sprintf("%s-collector", name),
					Namespace: namespace,
				}
				require.Eventually(t, func() bool {
					return k8sClient.Get(ctx, key, &corev1.ServiceAccount{}) == nil
				}, timeout, interval, "Collector ServiceAccount should be created")
			})

			t.Run("ClusterRole", func(t *testing.T) {
				key := types.NamespacedName{Name: fmt.Sprintf("%s-collector", name)}
				require.Eventually(t, func() bool {
					return k8sClient.Get(ctx, key, &rbacv1.ClusterRole{}) == nil
				}, timeout, interval, "Collector ClusterRole should be created")
			})

			t.Run("ClusterRoleBinding", func(t *testing.T) {
				key := types.NamespacedName{Name: fmt.Sprintf("%s-collector", name)}
				require.Eventually(t, func() bool {
					return k8sClient.Get(ctx, key, &rbacv1.ClusterRoleBinding{}) == nil
				}, timeout, interval, "Collector ClusterRoleBinding should be created")
			})
		})

		t.Run("Agent_RBAC_created", func(t *testing.T) {
			t.Run("ServiceAccount", func(t *testing.T) {
				key := types.NamespacedName{
					Name:      fmt.Sprintf("%s-agent", name),
					Namespace: namespace,
				}
				require.Eventually(t, func() bool {
					return k8sClient.Get(ctx, key, &corev1.ServiceAccount{}) == nil
				}, timeout, interval, "Agent ServiceAccount should be created")
			})

			t.Run("ClusterRole", func(t *testing.T) {
				key := types.NamespacedName{Name: fmt.Sprintf("%s-agent", name)}
				require.Eventually(t, func() bool {
					return k8sClient.Get(ctx, key, &rbacv1.ClusterRole{}) == nil
				}, timeout, interval, "Agent ClusterRole should be created")
			})

			t.Run("ClusterRoleBinding", func(t *testing.T) {
				key := types.NamespacedName{Name: fmt.Sprintf("%s-agent", name)}
				require.Eventually(t, func() bool {
					return k8sClient.Get(ctx, key, &rbacv1.ClusterRoleBinding{}) == nil
				}, timeout, interval, "Agent ClusterRoleBinding should be created")
			})
		})

		t.Run("Secrets_created", func(t *testing.T) {
			key := types.NamespacedName{
				Name:      fmt.Sprintf("%s-secrets", name),
				Namespace: namespace,
			}
			require.Eventually(t, func() bool {
				return k8sClient.Get(ctx, key, &corev1.Secret{}) == nil
			}, timeout, interval, "Secrets should be created")
		})

		t.Run("Status_reaches_Ready", func(t *testing.T) {
			require.Eventually(t, func() bool {
				fetched := &telemetryflowv1alpha1.TelemetryFlow{}
				_ = k8sClient.Get(ctx, types.NamespacedName{Name: name, Namespace: namespace}, fetched)
				return fetched.Status.Phase == "Ready"
			}, timeout, interval, "Status should reach Ready phase")
		})

		t.Run("Finalizer_is_set", func(t *testing.T) {
			fetched := &telemetryflowv1alpha1.TelemetryFlow{}
			err := k8sClient.Get(ctx, types.NamespacedName{Name: name, Namespace: namespace}, fetched)
			require.NoError(t, err)
			assert.Contains(t, fetched.Finalizers, "telemetryflow.io/finalizer")
		})

		t.Run("Component_statuses_populated", func(t *testing.T) {
			fetched := &telemetryflowv1alpha1.TelemetryFlow{}
			err := k8sClient.Get(ctx, types.NamespacedName{Name: name, Namespace: namespace}, fetched)
			require.NoError(t, err)
			assert.NotEmpty(t, fetched.Status.ComponentStatuses)
			assert.True(t, fetched.Status.Ready)
		})

		t.Run("Cleanup_on_deletion", func(t *testing.T) {
			tf := &telemetryflowv1alpha1.TelemetryFlow{}
			err := k8sClient.Get(ctx, types.NamespacedName{Name: name, Namespace: namespace}, tf)
			require.NoError(t, err)

			err = k8sClient.Delete(ctx, tf)
			require.NoError(t, err)

			require.Eventually(t, func() bool {
				return errors.IsNotFound(k8sClient.Get(ctx, types.NamespacedName{Name: name, Namespace: namespace}, &telemetryflowv1alpha1.TelemetryFlow{}))
			}, timeout, interval, "TelemetryFlow CR should be removed")

			require.Eventually(t, func() bool {
				return errors.IsNotFound(k8sClient.Get(ctx, types.NamespacedName{Name: fmt.Sprintf("%s-backend", name), Namespace: namespace}, &appsv1.Deployment{}))
			}, timeout, interval, "Backend Deployment should be cleaned up")

			require.Eventually(t, func() bool {
				return errors.IsNotFound(k8sClient.Get(ctx, types.NamespacedName{Name: fmt.Sprintf("%s-postgresql", name), Namespace: namespace}, &appsv1.StatefulSet{}))
			}, timeout, interval, "PostgreSQL StatefulSet should be cleaned up")

			require.Eventually(t, func() bool {
				return errors.IsNotFound(k8sClient.Get(ctx, types.NamespacedName{Name: fmt.Sprintf("%s-secrets", name), Namespace: namespace}, &corev1.Secret{}))
			}, timeout, interval, "Secrets should be cleaned up")
		})
	})
}

func TestReconcileMinimalDeployment(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping unit test in short mode")
	}

	const (
		namespace = "default"
		name      = "test-minimal"
	)

	t.Run("should deploy with only backend and postgresql", func(t *testing.T) {
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
					Enabled: false,
				},
				Secrets: telemetryflowv1alpha1.SecretsSpec{
					Create: true,
				},
			},
		}

		err := k8sClient.Create(ctx, tf)
		require.NoError(t, err)

		t.Cleanup(func() {
			tf := &telemetryflowv1alpha1.TelemetryFlow{}
			if err := k8sClient.Get(ctx, types.NamespacedName{Name: name, Namespace: namespace}, tf); err == nil {
				_ = k8sClient.Delete(ctx, tf)
			}
		})

		require.Eventually(t, func() bool {
			return k8sClient.Get(ctx, types.NamespacedName{
				Name: fmt.Sprintf("%s-postgresql", name), Namespace: namespace,
			}, &appsv1.StatefulSet{}) == nil
		}, timeout, interval, "PostgreSQL StatefulSet should be created")

		require.Eventually(t, func() bool {
			return k8sClient.Get(ctx, types.NamespacedName{
				Name: fmt.Sprintf("%s-backend", name), Namespace: namespace,
			}, &appsv1.Deployment{}) == nil
		}, timeout, interval, "Backend Deployment should be created")

		assert.Never(t, func() bool {
			return k8sClient.Get(ctx, types.NamespacedName{
				Name: fmt.Sprintf("%s-agent", name), Namespace: namespace,
			}, &appsv1.DaemonSet{}) == nil
		}, 5*time.Second, interval, "Agent DaemonSet should NOT be created")

		require.Eventually(t, func() bool {
			fetched := &telemetryflowv1alpha1.TelemetryFlow{}
			_ = k8sClient.Get(ctx, types.NamespacedName{Name: name, Namespace: namespace}, fetched)
			return fetched.Status.Phase == "Ready"
		}, timeout, interval, "Status should reach Ready phase")
	})
}

func TestReconcileUpdateReplicas(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping unit test in short mode")
	}

	const (
		namespace = "default"
		name      = "test-update"
	)

	t.Run("should update resources when CR spec changes", func(t *testing.T) {
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
				Secrets: telemetryflowv1alpha1.SecretsSpec{
					Create: true,
				},
			},
		}

		err := k8sClient.Create(ctx, tf)
		require.NoError(t, err)

		t.Cleanup(func() {
			tf := &telemetryflowv1alpha1.TelemetryFlow{}
			if err := k8sClient.Get(ctx, types.NamespacedName{Name: name, Namespace: namespace}, tf); err == nil {
				_ = k8sClient.Delete(ctx, tf)
			}
		})

		require.Eventually(t, func() bool {
			fetched := &telemetryflowv1alpha1.TelemetryFlow{}
			_ = k8sClient.Get(ctx, types.NamespacedName{Name: name, Namespace: namespace}, fetched)
			return fetched.Status.Phase == "Ready"
		}, timeout, interval, "Status should reach Ready phase")

		fetched := &telemetryflowv1alpha1.TelemetryFlow{}
		err = k8sClient.Get(ctx, types.NamespacedName{Name: name, Namespace: namespace}, fetched)
		require.NoError(t, err)

		fetched.Spec.Backend.Replicas = 3
		err = k8sClient.Update(ctx, fetched)
		require.NoError(t, err)

		require.Eventually(t, func() bool {
			deploy := &appsv1.Deployment{}
			_ = k8sClient.Get(ctx, types.NamespacedName{
				Name: fmt.Sprintf("%s-backend", name), Namespace: namespace,
			}, deploy)
			return deploy.Spec.Replicas != nil && *deploy.Spec.Replicas == 3
		}, timeout, interval, "Backend Deployment should have 3 replicas")
	})
}
