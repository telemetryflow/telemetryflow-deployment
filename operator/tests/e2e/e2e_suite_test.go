package e2e

import (
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	telemetryflowv1alpha1 "github.com/telemetryflow/telemetryflow-operator/api/v1alpha1"

	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes/scheme"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/client/config"
)

const (
	e2eNamespace       = "telemetryflow-e2e"
	e2eTimeout         = time.Second * 300
	e2ePollingInterval = time.Second * 2
)

var (
	k8sClient client.Client
)

func init() {
	_ = telemetryflowv1alpha1.AddToScheme(scheme.Scheme)
	_ = appsv1.AddToScheme(scheme.Scheme)
	_ = corev1.AddToScheme(scheme.Scheme)
}

var _ = BeforeSuite(func() {
	By("Loading kubeconfig for e2e tests")
	cfg, err := config.GetConfig()
	Expect(err).NotTo(HaveOccurred(), "Failed to get kubeconfig — ensure KUBECONFIG is set or ~/.kube/config exists")

	k8sClient, err = client.New(cfg, client.Options{Scheme: scheme.Scheme})
	Expect(err).NotTo(HaveOccurred())
	Expect(k8sClient).NotTo(BeNil())

	By("Creating e2e test namespace")
	ns := &corev1.Namespace{
		ObjectMeta: metav1.ObjectMeta{
			Name: e2eNamespace,
		},
	}
	err = k8sClient.Create(nil, ns)
	if err != nil && !errors.IsAlreadyExists(err) {
		Expect(err).NotTo(HaveOccurred())
	}
})

var _ = AfterSuite(func() {
	By("Cleaning up e2e test namespace")
	ns := &corev1.Namespace{
		ObjectMeta: metav1.ObjectMeta{
			Name: e2eNamespace,
		},
	}
	_ = k8sClient.Delete(nil, ns)
})
