package e2e

import (
	"fmt"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	telemetryflowv1alpha1 "github.com/telemetryflow/telemetryflow-operator/api/v1alpha1"

	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/types"
)

var _ = Describe("TelemetryFlow Operator E2E", func() {
	Context("Full platform deployment", func() {
		const (
			name = "e2e-full"
		)

		AfterEach(func() {
			By("Cleaning up TelemetryFlow CR")
			tf := &telemetryflowv1alpha1.TelemetryFlow{}
			if err := k8sClient.Get(nil, types.NamespacedName{Name: name, Namespace: e2eNamespace}, tf); err == nil {
				_ = k8sClient.Delete(nil, tf)
				Eventually(func() bool {
					return errors.IsNotFound(k8sClient.Get(nil, types.NamespacedName{Name: name, Namespace: e2eNamespace}, &telemetryflowv1alpha1.TelemetryFlow{}))
				}, e2eTimeout, e2ePollingInterval).Should(BeTrue())
			}
		})

		It("should deploy all components and reach Ready phase", func() {
			tf := &telemetryflowv1alpha1.TelemetryFlow{
				ObjectMeta: metav1.ObjectMeta{
					Name:      name,
					Namespace: e2eNamespace,
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
						Persistence: &telemetryflowv1alpha1.PersistenceSpec{
							Enabled: true,
							Size:    "1Gi",
						},
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
					},
					Backend: telemetryflowv1alpha1.BackendSpec{
						Image:    "telemetryflow/backend:latest",
						Replicas: 1,
					},
					Frontend: telemetryflowv1alpha1.FrontendSpec{
						Image:    "telemetryflow/frontend:latest",
						Replicas: 1,
					},
					Agent: telemetryflowv1alpha1.AgentSpec{
						Enabled: true,
						Image:   "telemetryflow/agent:latest",
					},
					Secrets: telemetryflowv1alpha1.SecretsSpec{
						Create: true,
					},
				},
			}

			By("Creating the TelemetryFlow CR")
			Expect(k8sClient.Create(nil, tf)).Should(Succeed())

			By("Waiting for PostgreSQL StatefulSet")
			Eventually(func() error {
				return k8sClient.Get(nil, types.NamespacedName{
					Name:      fmt.Sprintf("%s-postgresql", name),
					Namespace: e2eNamespace,
				}, &appsv1.StatefulSet{})
			}, e2eTimeout, e2ePollingInterval).Should(Succeed())

			By("Waiting for ClickHouse StatefulSet")
			Eventually(func() error {
				return k8sClient.Get(nil, types.NamespacedName{
					Name:      fmt.Sprintf("%s-clickhouse", name),
					Namespace: e2eNamespace,
				}, &appsv1.StatefulSet{})
			}, e2eTimeout, e2ePollingInterval).Should(Succeed())

			By("Waiting for Redis StatefulSet")
			Eventually(func() error {
				return k8sClient.Get(nil, types.NamespacedName{
					Name:      fmt.Sprintf("%s-redis", name),
					Namespace: e2eNamespace,
				}, &appsv1.StatefulSet{})
			}, e2eTimeout, e2ePollingInterval).Should(Succeed())

			By("Waiting for NATS StatefulSet")
			Eventually(func() error {
				return k8sClient.Get(nil, types.NamespacedName{
					Name:      fmt.Sprintf("%s-nats", name),
					Namespace: e2eNamespace,
				}, &appsv1.StatefulSet{})
			}, e2eTimeout, e2ePollingInterval).Should(Succeed())

			By("Waiting for Collector Deployment")
			Eventually(func() error {
				return k8sClient.Get(nil, types.NamespacedName{
					Name:      fmt.Sprintf("%s-collector", name),
					Namespace: e2eNamespace,
				}, &appsv1.Deployment{})
			}, e2eTimeout, e2ePollingInterval).Should(Succeed())

			By("Waiting for Backend Deployment")
			Eventually(func() error {
				return k8sClient.Get(nil, types.NamespacedName{
					Name:      fmt.Sprintf("%s-backend", name),
					Namespace: e2eNamespace,
				}, &appsv1.Deployment{})
			}, e2eTimeout, e2ePollingInterval).Should(Succeed())

			By("Waiting for Frontend Deployment")
			Eventually(func() error {
				return k8sClient.Get(nil, types.NamespacedName{
					Name:      fmt.Sprintf("%s-frontend", name),
					Namespace: e2eNamespace,
				}, &appsv1.Deployment{})
			}, e2eTimeout, e2ePollingInterval).Should(Succeed())

			By("Waiting for Agent DaemonSet")
			Eventually(func() error {
				return k8sClient.Get(nil, types.NamespacedName{
					Name:      fmt.Sprintf("%s-agent", name),
					Namespace: e2eNamespace,
				}, &appsv1.DaemonSet{})
			}, e2eTimeout, e2ePollingInterval).Should(Succeed())

			By("Waiting for Services to be created")
			services := []string{"redis", "bullmq-redis", "nats", "collector", "backend", "frontend"}
			for _, svc := range services {
				Eventually(func() error {
					return k8sClient.Get(nil, types.NamespacedName{
						Name:      fmt.Sprintf("%s-%s", name, svc),
						Namespace: e2eNamespace,
					}, &corev1.Service{})
				}, e2eTimeout, e2ePollingInterval).Should(Succeed())
			}

			By("Waiting for Secrets to be created")
			Eventually(func() error {
				return k8sClient.Get(nil, types.NamespacedName{
					Name:      fmt.Sprintf("%s-secrets", name),
					Namespace: e2eNamespace,
				}, &corev1.Secret{})
			}, e2eTimeout, e2ePollingInterval).Should(Succeed())

			By("Waiting for CR status to reach Ready phase")
			Eventually(func() string {
				fetched := &telemetryflowv1alpha1.TelemetryFlow{}
				_ = k8sClient.Get(nil, types.NamespacedName{Name: name, Namespace: e2eNamespace}, fetched)
				return fetched.Status.Phase
			}, e2eTimeout, e2ePollingInterval).Should(Equal("Ready"))

			By("Verifying finalizer is set")
			fetched := &telemetryflowv1alpha1.TelemetryFlow{}
			Expect(k8sClient.Get(nil, types.NamespacedName{Name: name, Namespace: e2eNamespace}, fetched)).Should(Succeed())
			Expect(fetched.Finalizers).To(ContainElement("telemetryflow.io/finalizer"))

			By("Verifying component statuses are populated")
			Expect(fetched.Status.ComponentStatuses).NotTo(BeEmpty())
			Expect(fetched.Status.Ready).To(BeTrue())
		})
	})

	Context("Minimal deployment", func() {
		const (
			name = "e2e-minimal"
		)

		AfterEach(func() {
			tf := &telemetryflowv1alpha1.TelemetryFlow{}
			if err := k8sClient.Get(nil, types.NamespacedName{Name: name, Namespace: e2eNamespace}, tf); err == nil {
				_ = k8sClient.Delete(nil, tf)
				Eventually(func() bool {
					return errors.IsNotFound(k8sClient.Get(nil, types.NamespacedName{Name: name, Namespace: e2eNamespace}, &telemetryflowv1alpha1.TelemetryFlow{}))
				}, e2eTimeout, e2ePollingInterval).Should(BeTrue())
			}
		})

		It("should deploy with only backend and postgresql", func() {
			tf := &telemetryflowv1alpha1.TelemetryFlow{
				ObjectMeta: metav1.ObjectMeta{
					Name:      name,
					Namespace: e2eNamespace,
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

			By("Creating a minimal TelemetryFlow CR")
			Expect(k8sClient.Create(nil, tf)).Should(Succeed())

			By("Waiting for PostgreSQL StatefulSet")
			Eventually(func() error {
				return k8sClient.Get(nil, types.NamespacedName{
					Name:      fmt.Sprintf("%s-postgresql", name),
					Namespace: e2eNamespace,
				}, &appsv1.StatefulSet{})
			}, e2eTimeout, e2ePollingInterval).Should(Succeed())

			By("Waiting for Backend Deployment")
			Eventually(func() error {
				return k8sClient.Get(nil, types.NamespacedName{
					Name:      fmt.Sprintf("%s-backend", name),
					Namespace: e2eNamespace,
				}, &appsv1.Deployment{})
			}, e2eTimeout, e2ePollingInterval).Should(Succeed())

			By("Verifying Agent DaemonSet is NOT created")
			Consistently(func() bool {
				return errors.IsNotFound(k8sClient.Get(nil, types.NamespacedName{
					Name:      fmt.Sprintf("%s-agent", name),
					Namespace: e2eNamespace,
				}, &appsv1.DaemonSet{}))
			}, 10*time.Second, e2ePollingInterval).Should(BeTrue())

			By("Waiting for Ready phase")
			Eventually(func() string {
				fetched := &telemetryflowv1alpha1.TelemetryFlow{}
				_ = k8sClient.Get(nil, types.NamespacedName{Name: name, Namespace: e2eNamespace}, fetched)
				return fetched.Status.Phase
			}, e2eTimeout, e2ePollingInterval).Should(Equal("Ready"))
		})
	})

	Context("Deletion and cleanup", func() {
		const (
			name = "e2e-delete"
		)

		It("should clean up all resources when CR is deleted", func() {
			tf := &telemetryflowv1alpha1.TelemetryFlow{
				ObjectMeta: metav1.ObjectMeta{
					Name:      name,
					Namespace: e2eNamespace,
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

			By("Creating TelemetryFlow CR")
			Expect(k8sClient.Create(nil, tf)).Should(Succeed())

			By("Waiting for Ready phase")
			Eventually(func() string {
				fetched := &telemetryflowv1alpha1.TelemetryFlow{}
				_ = k8sClient.Get(nil, types.NamespacedName{Name: name, Namespace: e2eNamespace}, fetched)
				return fetched.Status.Phase
			}, e2eTimeout, e2ePollingInterval).Should(Equal("Ready"))

			By("Deleting the TelemetryFlow CR")
			Expect(k8sClient.Delete(nil, tf)).Should(Succeed())

			By("Waiting for CR to be fully removed")
			Eventually(func() bool {
				return errors.IsNotFound(k8sClient.Get(nil, types.NamespacedName{Name: name, Namespace: e2eNamespace}, &telemetryflowv1alpha1.TelemetryFlow{}))
			}, e2eTimeout, e2ePollingInterval).Should(BeTrue())

			By("Verifying managed Deployments are cleaned up")
			Eventually(func() bool {
				return errors.IsNotFound(k8sClient.Get(nil, types.NamespacedName{
					Name:      fmt.Sprintf("%s-backend", name),
					Namespace: e2eNamespace,
				}, &appsv1.Deployment{}))
			}, e2eTimeout, e2ePollingInterval).Should(BeTrue())

			By("Verifying managed StatefulSets are cleaned up")
			Eventually(func() bool {
				return errors.IsNotFound(k8sClient.Get(nil, types.NamespacedName{
					Name:      fmt.Sprintf("%s-postgresql", name),
					Namespace: e2eNamespace,
				}, &appsv1.StatefulSet{}))
			}, e2eTimeout, e2ePollingInterval).Should(BeTrue())

			By("Verifying managed Secrets are cleaned up")
			Eventually(func() bool {
				return errors.IsNotFound(k8sClient.Get(nil, types.NamespacedName{
					Name:      fmt.Sprintf("%s-secrets", name),
					Namespace: e2eNamespace,
				}, &corev1.Secret{}))
			}, e2eTimeout, e2ePollingInterval).Should(BeTrue())
		})
	})

	Context("Update and reconciliation", func() {
		const (
			name = "e2e-update"
		)

		AfterEach(func() {
			tf := &telemetryflowv1alpha1.TelemetryFlow{}
			if err := k8sClient.Get(nil, types.NamespacedName{Name: name, Namespace: e2eNamespace}, tf); err == nil {
				_ = k8sClient.Delete(nil, tf)
				Eventually(func() bool {
					return errors.IsNotFound(k8sClient.Get(nil, types.NamespacedName{Name: name, Namespace: e2eNamespace}, &telemetryflowv1alpha1.TelemetryFlow{}))
				}, e2eTimeout, e2ePollingInterval).Should(BeTrue())
			}
		})

		It("should update resources when CR spec changes", func() {
			tf := &telemetryflowv1alpha1.TelemetryFlow{
				ObjectMeta: metav1.ObjectMeta{
					Name:      name,
					Namespace: e2eNamespace,
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

			By("Creating TelemetryFlow with 1 backend replica")
			Expect(k8sClient.Create(nil, tf)).Should(Succeed())

			By("Waiting for Ready phase")
			Eventually(func() string {
				fetched := &telemetryflowv1alpha1.TelemetryFlow{}
				_ = k8sClient.Get(nil, types.NamespacedName{Name: name, Namespace: e2eNamespace}, fetched)
				return fetched.Status.Phase
			}, e2eTimeout, e2ePollingInterval).Should(Equal("Ready"))

			By("Updating backend replicas to 3")
			fetched := &telemetryflowv1alpha1.TelemetryFlow{}
			Expect(k8sClient.Get(nil, types.NamespacedName{Name: name, Namespace: e2eNamespace}, fetched)).Should(Succeed())
			fetched.Spec.Backend.Replicas = 3
			Expect(k8sClient.Update(nil, fetched)).Should(Succeed())

			By("Waiting for Backend Deployment to reflect 3 replicas")
			Eventually(func() int32 {
				deploy := &appsv1.Deployment{}
				_ = k8sClient.Get(nil, types.NamespacedName{
					Name:      fmt.Sprintf("%s-backend", name),
					Namespace: e2eNamespace,
				}, deploy)
				if deploy.Spec.Replicas != nil {
					return *deploy.Spec.Replicas
				}
				return 0
			}, e2eTimeout, e2ePollingInterval).Should(Equal(int32(3)))

			By("Verifying observed generation is updated")
			Eventually(func() int64 {
				updated := &telemetryflowv1alpha1.TelemetryFlow{}
				_ = k8sClient.Get(nil, types.NamespacedName{Name: name, Namespace: e2eNamespace}, updated)
				return updated.Status.ObservedGeneration
			}, e2eTimeout, e2ePollingInterval).Should(BeNumerically(">=", fetched.Generation))
		})
	})
})
