package controller

import (
	"context"
	"fmt"
	"time"

	appsv1 "k8s.io/api/apps/v1"
	autoscalingv2 "k8s.io/api/autoscaling/v2"
	corev1 "k8s.io/api/core/v1"
	networkingv1 "k8s.io/api/networking/v1"
	rbacv1 "k8s.io/api/rbac/v1"
	"k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/api/resource"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/types"
	"k8s.io/apimachinery/pkg/util/intstr"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/controller/controllerutil"
	"sigs.k8s.io/controller-runtime/pkg/log"

	telemetryflowv1alpha1 "github.com/telemetryflow/telemetryflow-operator/api/v1alpha1"
)

const (
	telemetryFlowFinalizer = "telemetryflow.id/finalizer"
	requeueAfter           = 5 * time.Second
)

// +kubebuilder:rbac:groups=rbac.authorization.k8s.io,resources=clusterroles;clusterrolebindings;roles;rolebindings;serviceaccounts,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=networking.k8s.io,resources=ingresses;ingresses/finalizers;ingressclasses,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=autoscaling,resources=horizontalpodautoscalers;horizontalpodautoscalers/finalizers,verbs=get;list;watch;create;update;patch;delete
type TelemetryFlowReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

func (r *TelemetryFlowReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	logger := log.FromContext(ctx)

	tf := &telemetryflowv1alpha1.TelemetryFlow{}
	if err := r.Get(ctx, req.NamespacedName, tf); err != nil {
		if errors.IsNotFound(err) {
			logger.Info("TelemetryFlow resource not found, ignoring since object must be deleted")
			return ctrl.Result{}, nil
		}
		logger.Error(err, "Failed to get TelemetryFlow")
		return ctrl.Result{}, err
	}

	if tf.DeletionTimestamp != nil {
		return r.handleDeletion(ctx, tf)
	}

	if !controllerutil.ContainsFinalizer(tf, telemetryFlowFinalizer) {
		controllerutil.AddFinalizer(tf, telemetryFlowFinalizer)
		if err := r.Update(ctx, tf); err != nil {
			logger.Error(err, "Failed to add finalizer")
			return ctrl.Result{}, err
		}
		return ctrl.Result{Requeue: true}, nil
	}

	r.setStatusCondition(tf, metav1.Condition{
		Type: "Progressing", Status: metav1.ConditionTrue, Reason: "Reconciling", Message: "Starting reconciliation",
	})
	tf.Status.Phase = "Deploying"
	tf.Status.Message = "Reconciling components"
	tf.Status.ObservedGeneration = tf.Generation
	_ = r.Status().Update(ctx, tf)

	steps := []struct {
		name string
		fn   func(context.Context, *telemetryflowv1alpha1.TelemetryFlow) error
	}{
		{"postgresql", r.reconcilePostgreSQL},
		{"clickhouse", r.reconcileClickHouse},
		{"redis", r.reconcileRedis},
		{"bullmq-redis", r.reconcileBullMQRedis},
		{"nats", r.reconcileNATS},
		{"collector-rbac", r.reconcileCollectorRBAC},
		{"collector", r.reconcileCollector},
		{"agent-rbac", r.reconcileAgentRBAC},
		{"agent-daemonset", r.reconcileAgentDaemonSet},
		{"agent-k8s", r.reconcileAgentK8sDeployment},
		{"backend", r.reconcileBackend},
		{"frontend", r.reconcileFrontend},
		{"backend-ingress", r.reconcileBackendIngress},
		{"frontend-ingress", r.reconcileFrontendIngress},
		{"backend-hpa", r.reconcileBackendHPA},
	}

	for _, step := range steps {
		if err := step.fn(ctx, tf); err != nil {
			logger.Error(err, "Failed to reconcile component", "component", step.name)
			r.setStatusCondition(tf, metav1.Condition{
				Type: "Ready", Status: metav1.ConditionFalse, Reason: "ReconcileError",
				Message: fmt.Sprintf("Failed to reconcile %s: %v", step.name, err),
			})
			tf.Status.Phase = "Failed"
			tf.Status.Message = fmt.Sprintf("Failed to reconcile %s: %v", step.name, err)
			_ = r.Status().Update(ctx, tf)
			return ctrl.Result{RequeueAfter: requeueAfter}, nil
		}
		if tf.Status.ComponentStatuses == nil {
			tf.Status.ComponentStatuses = make(map[string]telemetryflowv1alpha1.ComponentStatus)
		}
		tf.Status.ComponentStatuses[step.name] = telemetryflowv1alpha1.ComponentStatus{
			Ready: true, Message: "Reconciled successfully",
		}
	}

	if tf.Spec.Secrets.Create {
		if err := r.reconcileSecrets(ctx, tf); err != nil {
			logger.Error(err, "Failed to reconcile secrets")
			return ctrl.Result{RequeueAfter: requeueAfter}, nil
		}
	}

	r.setStatusCondition(tf, metav1.Condition{
		Type: "Ready", Status: metav1.ConditionTrue, Reason: "ReconcileComplete",
	})
	tf.Status.Phase = "Ready"
	tf.Status.Ready = true
	tf.Status.Message = "All components reconciled successfully"
	tf.Status.ObservedGeneration = tf.Generation
	_ = r.Status().Update(ctx, tf)

	return ctrl.Result{}, nil
}

func (r *TelemetryFlowReconciler) handleDeletion(ctx context.Context, tf *telemetryflowv1alpha1.TelemetryFlow) (ctrl.Result, error) {
	logger := log.FromContext(ctx)

	if !controllerutil.ContainsFinalizer(tf, telemetryFlowFinalizer) {
		return ctrl.Result{}, nil
	}

	logger.Info("Performing cleanup for TelemetryFlow", "name", tf.Name)

	tf.Status.Phase = "Terminating"
	tf.Status.Message = "Cleaning up resources"
	_ = r.Status().Update(ctx, tf)

	controllerutil.RemoveFinalizer(tf, telemetryFlowFinalizer)
	if err := r.Update(ctx, tf); err != nil {
		logger.Error(err, "Failed to remove finalizer")
		return ctrl.Result{}, err
	}

	logger.Info("Successfully cleaned up TelemetryFlow", "name", tf.Name)
	return ctrl.Result{}, nil
}

// =============================================================================
// Collector — RBAC (ServiceAccount + ClusterRole + ClusterRoleBinding)
// =============================================================================

func (r *TelemetryFlowReconciler) reconcileCollectorRBAC(ctx context.Context, tf *telemetryflowv1alpha1.TelemetryFlow) error {
	saName := fmt.Sprintf("%s-collector", tf.Name)
	if tf.Spec.Collector.ServiceAccount.Name != "" {
		saName = tf.Spec.Collector.ServiceAccount.Name
	}

	sa := &corev1.ServiceAccount{
		ObjectMeta: metav1.ObjectMeta{
			Name:        saName,
			Namespace:   tf.Namespace,
			Labels:      r.labelsForComponent(tf.Name, "collector"),
			Annotations: tf.Spec.Collector.ServiceAccount.Annotations,
		},
	}
	if err := r.reconcileRaw(ctx, sa, tf); err != nil {
		return err
	}

	cr := &rbacv1.ClusterRole{
		ObjectMeta: metav1.ObjectMeta{
			Name:   fmt.Sprintf("%s-collector", tf.Name),
			Labels: r.labelsForComponent(tf.Name, "collector"),
		},
		Rules: []rbacv1.PolicyRule{
			{APIGroups: []string{""}, Resources: []string{"nodes", "pods", "namespaces", "endpoints", "services", "replicationcontrollers"}, Verbs: []string{"get", "list", "watch"}},
			{APIGroups: []string{"apps"}, Resources: []string{"deployments", "replicasets", "statefulsets", "daemonsets"}, Verbs: []string{"get", "list", "watch"}},
			{NonResourceURLs: []string{"/metrics", "/metrics/cadvisor"}, Verbs: []string{"get"}},
		},
	}
	if err := r.reconcileRaw(ctx, cr, tf); err != nil {
		return err
	}

	crb := &rbacv1.ClusterRoleBinding{
		ObjectMeta: metav1.ObjectMeta{
			Name:   fmt.Sprintf("%s-collector", tf.Name),
			Labels: r.labelsForComponent(tf.Name, "collector"),
		},
		RoleRef: rbacv1.RoleRef{
			APIGroup: "rbac.authorization.k8s.io",
			Kind:     "ClusterRole",
			Name:     fmt.Sprintf("%s-collector", tf.Name),
		},
		Subjects: []rbacv1.Subject{
			{Kind: "ServiceAccount", Name: saName, Namespace: tf.Namespace},
		},
	}
	return r.reconcileRaw(ctx, crb, tf)
}

// =============================================================================
// Collector — Deployment with ConfigMap, env, ports, queue volume
// =============================================================================

func (r *TelemetryFlowReconciler) reconcileCollector(ctx context.Context, tf *telemetryflowv1alpha1.TelemetryFlow) error {
	spec := tf.Spec.Collector
	replicas := spec.Replicas
	if replicas == 0 {
		replicas = 1
	}
	image := spec.Image
	if image == "" {
		image = "telemetryflow/telemetryflow-collector:1.2.1"
	}

	saName := fmt.Sprintf("%s-collector", tf.Name)
	if spec.ServiceAccount.Name != "" {
		saName = spec.ServiceAccount.Name
	}

	if spec.Config != "" {
		cm := r.buildCollectorConfigMap(tf, spec.Config)
		if err := r.reconcileConfigMap(ctx, cm, tf); err != nil {
			return err
		}
	}

	labels := r.labelsForComponent(tf.Name, "collector")
	env := r.buildCollectorEnv(tf, spec)

	ports := spec.Ports
	if len(ports) == 0 {
		ports = []telemetryflowv1alpha1.ContainerPortSpec{
			{ContainerPort: 4317, Name: "grpc"},
			{ContainerPort: 4318, Name: "http"},
			{ContainerPort: 8889, Name: "prometheus"},
			{ContainerPort: 13133, Name: "health"},
		}
	}

	volumes := []corev1.Volume{
		{Name: "config", VolumeSource: corev1.VolumeSource{ConfigMap: &corev1.ConfigMapVolumeSource{
			LocalObjectReference: corev1.LocalObjectReference{Name: fmt.Sprintf("%s-collector-config", tf.Name)},
		}}},
		{Name: "queue", VolumeSource: corev1.VolumeSource{EmptyDir: &corev1.EmptyDirVolumeSource{
			Medium:    corev1.StorageMediumDefault,
			SizeLimit: resourceQuantity("500Mi"),
		}}},
	}
	volumeMounts := []corev1.VolumeMount{
		{Name: "config", MountPath: "/etc/tfo-collector", ReadOnly: true},
		{Name: "queue", MountPath: "/var/lib/tfo-collector/queue"},
	}

	deploy := &appsv1.Deployment{
		ObjectMeta: metav1.ObjectMeta{
			Name:      fmt.Sprintf("%s-collector", tf.Name),
			Namespace: tf.Namespace,
			Labels:    labels,
		},
		Spec: appsv1.DeploymentSpec{
			Replicas: &replicas,
			Selector: &metav1.LabelSelector{MatchLabels: labels},
			Template: corev1.PodTemplateSpec{
				ObjectMeta: metav1.ObjectMeta{Labels: labels},
				Spec: corev1.PodSpec{
					ServiceAccountName: saName,
					SecurityContext:    r.collectorSecurityContext(spec.Security),
					Containers: []corev1.Container{{
						Name:         "collector",
						Image:        image,
						Ports:        convertPorts(ports),
						Env:          env,
						VolumeMounts: volumeMounts,
						Resources:    r.buildResourceRequirements(spec.Resources),
						LivenessProbe: &corev1.Probe{
							ProbeHandler: corev1.ProbeHandler{HTTPGet: &corev1.HTTPGetAction{
								Path: "/", Port: intstr.FromInt(13133),
							}},
							InitialDelaySeconds: 30, PeriodSeconds: 15, TimeoutSeconds: 5,
						},
						ReadinessProbe: &corev1.Probe{
							ProbeHandler: corev1.ProbeHandler{HTTPGet: &corev1.HTTPGetAction{
								Path: "/", Port: intstr.FromInt(13133),
							}},
							InitialDelaySeconds: 10, PeriodSeconds: 10, TimeoutSeconds: 5,
						},
					}},
					Volumes: volumes,
				},
			},
		},
	}

	svc := r.buildMultiPortServiceFull(tf, "collector", convertServicePorts(ports), serviceAnnotations(spec.Service), serviceType(spec.Service))
	r.applyScheduling(&deploy.Spec.Template.Spec, spec.Scheduling)
	if err := r.reconcileService(ctx, svc, tf); err != nil {
		return err
	}
	return r.reconcileDeployment(ctx, deploy, tf)
}

// =============================================================================
// Agent — RBAC (ServiceAccount + ClusterRole + ClusterRoleBinding)
// =============================================================================

func (r *TelemetryFlowReconciler) reconcileAgentRBAC(ctx context.Context, tf *telemetryflowv1alpha1.TelemetryFlow) error {
	if !tf.Spec.Agent.Enabled {
		return nil
	}
	saName := fmt.Sprintf("%s-agent", tf.Name)
	if tf.Spec.Agent.ServiceAccount.Name != "" {
		saName = tf.Spec.Agent.ServiceAccount.Name
	}

	sa := &corev1.ServiceAccount{
		ObjectMeta: metav1.ObjectMeta{
			Name:        saName,
			Namespace:   tf.Namespace,
			Labels:      r.labelsForComponent(tf.Name, "agent"),
			Annotations: tf.Spec.Agent.ServiceAccount.Annotations,
		},
	}
	if err := r.reconcileRaw(ctx, sa, tf); err != nil {
		return err
	}

	cr := &rbacv1.ClusterRole{
		ObjectMeta: metav1.ObjectMeta{
			Name:   fmt.Sprintf("%s-agent", tf.Name),
			Labels: r.labelsForComponent(tf.Name, "agent"),
		},
		Rules: []rbacv1.PolicyRule{
			{APIGroups: []string{""}, Resources: []string{"nodes", "nodes/metrics", "nodes/stats", "nodes/proxy", "pods", "services", "endpoints", "namespaces", "events", "persistentvolumes", "persistentvolumeclaims", "resourcequotas", "limitranges", "configmaps", "secrets"}, Verbs: []string{"get", "list", "watch"}},
			{APIGroups: []string{""}, Resources: []string{"pods/log"}, Verbs: []string{"get", "list"}},
			{APIGroups: []string{"apps"}, Resources: []string{"deployments", "statefulsets", "daemonsets", "replicasets"}, Verbs: []string{"get", "list", "watch"}},
			{APIGroups: []string{"batch"}, Resources: []string{"jobs", "cronjobs"}, Verbs: []string{"get", "list", "watch"}},
			{APIGroups: []string{"autoscaling"}, Resources: []string{"horizontalpodautoscalers"}, Verbs: []string{"get", "list", "watch"}},
			{APIGroups: []string{"networking.k8s.io"}, Resources: []string{"ingresses"}, Verbs: []string{"get", "list", "watch"}},
			{APIGroups: []string{"discovery.k8s.io"}, Resources: []string{"endpointslices"}, Verbs: []string{"get", "list", "watch"}},
			{APIGroups: []string{"storage.k8s.io"}, Resources: []string{"storageclasses", "volumeattachments"}, Verbs: []string{"get", "list", "watch"}},
			{APIGroups: []string{"policy"}, Resources: []string{"poddisruptionbudgets"}, Verbs: []string{"get", "list", "watch"}},
			{APIGroups: []string{"events.k8s.io"}, Resources: []string{"events"}, Verbs: []string{"get", "list", "watch"}},
			{APIGroups: []string{"metrics.k8s.io"}, Resources: []string{"nodes", "pods"}, Verbs: []string{"get", "list"}},
			{NonResourceURLs: []string{"/metrics", "/metrics/cadvisor"}, Verbs: []string{"get"}},
		},
	}
	if err := r.reconcileRaw(ctx, cr, tf); err != nil {
		return err
	}

	crb := &rbacv1.ClusterRoleBinding{
		ObjectMeta: metav1.ObjectMeta{
			Name:   fmt.Sprintf("%s-agent", tf.Name),
			Labels: r.labelsForComponent(tf.Name, "agent"),
		},
		RoleRef: rbacv1.RoleRef{
			APIGroup: "rbac.authorization.k8s.io",
			Kind:     "ClusterRole",
			Name:     fmt.Sprintf("%s-agent", tf.Name),
		},
		Subjects: []rbacv1.Subject{
			{Kind: "ServiceAccount", Name: saName, Namespace: tf.Namespace},
		},
	}
	return r.reconcileRaw(ctx, crb, tf)
}

// =============================================================================
// Agent — DaemonSet (per-node OS metrics via node_exporter)
// =============================================================================

func (r *TelemetryFlowReconciler) reconcileAgentDaemonSet(ctx context.Context, tf *telemetryflowv1alpha1.TelemetryFlow) error {
	if !tf.Spec.Agent.Enabled {
		return nil
	}

	nodeSpec := tf.Spec.Agent.Node
	if !nodeSpec.Enabled {
		return nil
	}

	image := nodeSpec.Image
	if image == "" {
		image = tf.Spec.Agent.Image
	}
	if image == "" {
		image = "telemetryflow/telemetryflow-agent:1.2.0"
	}

	saName := fmt.Sprintf("%s-agent", tf.Name)
	if tf.Spec.Agent.ServiceAccount.Name != "" {
		saName = tf.Spec.Agent.ServiceAccount.Name
	}

	if nodeSpec.Config != "" {
		cm := r.buildAgentNodeConfigMap(tf, nodeSpec.Config)
		if err := r.reconcileConfigMap(ctx, cm, tf); err != nil {
			return err
		}
	}

	labels := r.labelsForComponent(tf.Name, "agent-node")
	truePtr := true
	falsePtr := false

	env := r.buildAgentNodeEnv(tf)

	ds := &appsv1.DaemonSet{
		ObjectMeta: metav1.ObjectMeta{
			Name:      fmt.Sprintf("%s-agent", tf.Name),
			Namespace: tf.Namespace,
			Labels:    labels,
		},
		Spec: appsv1.DaemonSetSpec{
			Selector: &metav1.LabelSelector{MatchLabels: labels},
			Template: corev1.PodTemplateSpec{
				ObjectMeta: metav1.ObjectMeta{Labels: labels},
				Spec: corev1.PodSpec{
					ServiceAccountName: saName,
					SecurityContext: &corev1.PodSecurityContext{
						SeccompProfile: &corev1.SeccompProfile{Type: corev1.SeccompProfileTypeRuntimeDefault},
					},
					Tolerations: []corev1.Toleration{
						{Operator: corev1.TolerationOpExists, Effect: corev1.TaintEffectNoSchedule},
						{Operator: corev1.TolerationOpExists, Effect: corev1.TaintEffectNoExecute},
					},
					NodeSelector: map[string]string{"kubernetes.io/os": "linux"},
					Containers: []corev1.Container{{
						Name:      "tfo-agent",
						Image:     image,
						Env:       env,
						Ports:     []corev1.ContainerPort{{ContainerPort: 8888, Name: "metrics"}},
						Resources: r.buildResourceRequirements(nodeSpec.Resources),
						VolumeMounts: []corev1.VolumeMount{
							{Name: "config", MountPath: "/etc/tfo-agent", ReadOnly: true},
							{Name: "buffer", MountPath: "/var/lib/tfo-agent/buffer"},
							{Name: "proc", MountPath: "/host/proc", ReadOnly: true},
							{Name: "sys", MountPath: "/host/sys", ReadOnly: true},
							{Name: "root", MountPath: "/host/root", ReadOnly: true, MountPropagation: &[]corev1.MountPropagationMode{corev1.MountPropagationHostToContainer}[0]},
							{Name: "varlog", MountPath: "/var/log", ReadOnly: true},
							{Name: "varlogcontainers", MountPath: "/var/log/containers", ReadOnly: true},
							{Name: "fluentbit-storage", MountPath: "/tmp/tfo-agent-fluentbit"},
						},
						SecurityContext: &corev1.SecurityContext{
							RunAsUser:                int64Ptr(0),
							RunAsGroup:               int64Ptr(0),
							ReadOnlyRootFilesystem:   &truePtr,
							AllowPrivilegeEscalation: &falsePtr,
							SeccompProfile:           &corev1.SeccompProfile{Type: corev1.SeccompProfileTypeRuntimeDefault},
							Capabilities:             &corev1.Capabilities{Drop: []corev1.Capability{"ALL"}, Add: []corev1.Capability{"SYS_PTRACE"}},
						},
					}},
					Volumes: []corev1.Volume{
						{Name: "config", VolumeSource: corev1.VolumeSource{ConfigMap: &corev1.ConfigMapVolumeSource{
							LocalObjectReference: corev1.LocalObjectReference{Name: fmt.Sprintf("%s-agent-node-config", tf.Name)},
						}}},
						{Name: "buffer", VolumeSource: corev1.VolumeSource{EmptyDir: &corev1.EmptyDirVolumeSource{SizeLimit: resourceQuantity("200Mi")}}},
						{Name: "proc", VolumeSource: corev1.VolumeSource{HostPath: &corev1.HostPathVolumeSource{Path: "/proc"}}},
						{Name: "sys", VolumeSource: corev1.VolumeSource{HostPath: &corev1.HostPathVolumeSource{Path: "/sys"}}},
						{Name: "root", VolumeSource: corev1.VolumeSource{HostPath: &corev1.HostPathVolumeSource{Path: "/"}}},
						{Name: "varlog", VolumeSource: corev1.VolumeSource{HostPath: &corev1.HostPathVolumeSource{Path: "/var/log"}}},
						{Name: "varlogcontainers", VolumeSource: corev1.VolumeSource{HostPath: &corev1.HostPathVolumeSource{Path: "/var/log/containers"}}},
						{Name: "fluentbit-storage", VolumeSource: corev1.VolumeSource{EmptyDir: &corev1.EmptyDirVolumeSource{SizeLimit: resourceQuantity("200Mi")}}},
					},
				},
			},
		},
	}
	r.applyScheduling(&ds.Spec.Template.Spec, nodeSpec.Scheduling)
	return r.reconcileDaemonSet(ctx, ds, tf)
}

// =============================================================================
// Agent — K8s Deployment (cluster-wide Kubernetes state collection)
// =============================================================================

func (r *TelemetryFlowReconciler) reconcileAgentK8sDeployment(ctx context.Context, tf *telemetryflowv1alpha1.TelemetryFlow) error {
	if !tf.Spec.Agent.Enabled {
		return nil
	}

	k8sSpec := tf.Spec.Agent.Kubernetes
	if !k8sSpec.Enabled {
		return nil
	}

	image := k8sSpec.Image
	if image == "" {
		image = tf.Spec.Agent.Image
	}
	if image == "" {
		image = "telemetryflow/telemetryflow-agent:1.2.0"
	}

	replicas := k8sSpec.Replicas
	if replicas == 0 {
		replicas = 1
	}

	saName := fmt.Sprintf("%s-agent", tf.Name)
	if tf.Spec.Agent.ServiceAccount.Name != "" {
		saName = tf.Spec.Agent.ServiceAccount.Name
	}

	if k8sSpec.Config != "" {
		cm := r.buildAgentK8sConfigMap(tf, k8sSpec.Config)
		if err := r.reconcileConfigMap(ctx, cm, tf); err != nil {
			return err
		}
	}

	labels := r.labelsForComponent(tf.Name, "agent-k8s")
	truePtr := true
	falsePtr := false

	env := r.buildAgentK8sEnv(tf)

	deploy := &appsv1.Deployment{
		ObjectMeta: metav1.ObjectMeta{
			Name:      fmt.Sprintf("%s-agent-k8s", tf.Name),
			Namespace: tf.Namespace,
			Labels:    labels,
		},
		Spec: appsv1.DeploymentSpec{
			Replicas: &replicas,
			Selector: &metav1.LabelSelector{MatchLabels: labels},
			Template: corev1.PodTemplateSpec{
				ObjectMeta: metav1.ObjectMeta{Labels: labels},
				Spec: corev1.PodSpec{
					ServiceAccountName: saName,
					SecurityContext: &corev1.PodSecurityContext{
						RunAsNonRoot:   &truePtr,
						SeccompProfile: &corev1.SeccompProfile{Type: corev1.SeccompProfileTypeRuntimeDefault},
					},
					Containers: []corev1.Container{{
						Name:      "tfo-agent-k8s",
						Image:     image,
						Env:       env,
						Resources: r.buildResourceRequirements(k8sSpec.Resources),
						VolumeMounts: []corev1.VolumeMount{
							{Name: "config", MountPath: "/etc/tfo-agent", ReadOnly: true},
							{Name: "buffer", MountPath: "/var/lib/tfo-agent/buffer"},
							{Name: "hostfs", MountPath: "/hostfs", ReadOnly: true, MountPropagation: &[]corev1.MountPropagationMode{corev1.MountPropagationHostToContainer}[0]},
						},
						SecurityContext: &corev1.SecurityContext{
							RunAsNonRoot:             &truePtr,
							RunAsUser:                int64Ptr(65534),
							RunAsGroup:               int64Ptr(65534),
							ReadOnlyRootFilesystem:   &truePtr,
							AllowPrivilegeEscalation: &falsePtr,
							SeccompProfile:           &corev1.SeccompProfile{Type: corev1.SeccompProfileTypeRuntimeDefault},
							Capabilities:             &corev1.Capabilities{Drop: []corev1.Capability{"ALL"}},
						},
					}},
					Volumes: []corev1.Volume{
						{Name: "config", VolumeSource: corev1.VolumeSource{ConfigMap: &corev1.ConfigMapVolumeSource{
							LocalObjectReference: corev1.LocalObjectReference{Name: fmt.Sprintf("%s-agent-k8s-config", tf.Name)},
						}}},
						{Name: "buffer", VolumeSource: corev1.VolumeSource{EmptyDir: &corev1.EmptyDirVolumeSource{SizeLimit: resourceQuantity("100Mi")}}},
						{Name: "hostfs", VolumeSource: corev1.VolumeSource{HostPath: &corev1.HostPathVolumeSource{Path: "/"}}},
					},
				},
			},
		},
	}
	r.applyScheduling(&deploy.Spec.Template.Spec, k8sSpec.Scheduling)
	return r.reconcileDeployment(ctx, deploy, tf)
}

// =============================================================================
// Infrastructure components (PostgreSQL, ClickHouse, Redis, NATS, Backend, Frontend)
// =============================================================================

func (r *TelemetryFlowReconciler) reconcilePostgreSQL(ctx context.Context, tf *telemetryflowv1alpha1.TelemetryFlow) error {
	spec := tf.Spec.PostgreSQL
	replicas := spec.Replicas
	if replicas == 0 {
		replicas = 1
	}
	image := spec.Image
	if image == "" {
		image = "postgres:16-alpine"
	}

	sts := r.buildStatefulSetFull(tf, "postgresql", image, replicas, spec.Resources, spec.Persistence, nil, spec.Scheduling)
	return r.reconcileStatefulSet(ctx, sts, tf)
}

func (r *TelemetryFlowReconciler) reconcileClickHouse(ctx context.Context, tf *telemetryflowv1alpha1.TelemetryFlow) error {
	spec := tf.Spec.ClickHouse
	replicas := spec.Replicas
	if replicas == 0 {
		replicas = 1
	}
	image := spec.Image
	if image == "" {
		image = "clickhouse/clickhouse-server:24-alpine"
	}

	sts := r.buildStatefulSetFull(tf, "clickhouse", image, replicas, spec.Resources, spec.Persistence, nil, spec.Scheduling)
	return r.reconcileStatefulSet(ctx, sts, tf)
}

func (r *TelemetryFlowReconciler) reconcileRedis(ctx context.Context, tf *telemetryflowv1alpha1.TelemetryFlow) error {
	spec := tf.Spec.Redis
	image := spec.Image
	if image == "" {
		image = "redis:7-alpine"
	}

	sts := r.buildStatefulSet(tf, "redis", image, 1, spec.Resources, spec.Persistence, []corev1.ContainerPort{{ContainerPort: 6379, Name: "redis"}})
	svc := r.buildService(tf, "redis", 6379)
	if err := r.reconcileService(ctx, svc, tf); err != nil {
		return err
	}
	return r.reconcileStatefulSet(ctx, sts, tf)
}

func (r *TelemetryFlowReconciler) reconcileBullMQRedis(ctx context.Context, tf *telemetryflowv1alpha1.TelemetryFlow) error {
	spec := tf.Spec.BullMQRedis
	image := spec.Image
	if image == "" {
		image = "redis:7-alpine"
	}

	sts := r.buildStatefulSet(tf, "bullmq-redis", image, 1, spec.Resources, spec.Persistence, []corev1.ContainerPort{{ContainerPort: 6379, Name: "redis"}})
	svc := r.buildService(tf, "bullmq-redis", 6379)
	if err := r.reconcileService(ctx, svc, tf); err != nil {
		return err
	}
	return r.reconcileStatefulSet(ctx, sts, tf)
}

func (r *TelemetryFlowReconciler) reconcileNATS(ctx context.Context, tf *telemetryflowv1alpha1.TelemetryFlow) error {
	spec := tf.Spec.NATS
	image := spec.Image
	if image == "" {
		image = "nats:2-alpine"
	}

	args := []string{"--port", "4222"}
	if spec.JetStreamEnabled {
		args = append(args, "--jetstream")
	}

	ports := []corev1.ContainerPort{
		{ContainerPort: 4222, Name: "client"},
		{ContainerPort: 8222, Name: "monitor"},
	}

	sts := r.buildStatefulSetWithArgs(tf, "nats", image, 1, spec.Resources, spec.Persistence, ports, args)
	svc := r.buildService(tf, "nats", 4222)
	if err := r.reconcileService(ctx, svc, tf); err != nil {
		return err
	}
	return r.reconcileStatefulSet(ctx, sts, tf)
}

func (r *TelemetryFlowReconciler) reconcileBackend(ctx context.Context, tf *telemetryflowv1alpha1.TelemetryFlow) error {
	spec := tf.Spec.Backend
	replicas := spec.Replicas
	if replicas == 0 {
		replicas = 1
	}
	image := spec.Image
	if image == "" {
		image = "telemetryflow/backend:latest"
	}

	deploy := r.buildDeploymentFull(tf, "backend", image, replicas, spec.Resources, []corev1.ContainerPort{{ContainerPort: 8080, Name: "http"}}, spec.Scheduling)
	svc := r.buildServiceFull(tf, "backend", 8080, serviceAnnotations(spec.Service), serviceType(spec.Service))
	if err := r.reconcileService(ctx, svc, tf); err != nil {
		return err
	}
	return r.reconcileDeployment(ctx, deploy, tf)
}

func (r *TelemetryFlowReconciler) reconcileFrontend(ctx context.Context, tf *telemetryflowv1alpha1.TelemetryFlow) error {
	spec := tf.Spec.Frontend
	replicas := spec.Replicas
	if replicas == 0 {
		replicas = 1
	}
	image := spec.Image
	if image == "" {
		image = "telemetryflow/frontend:latest"
	}

	deploy := r.buildDeploymentFull(tf, "frontend", image, replicas, spec.Resources, []corev1.ContainerPort{{ContainerPort: 3000, Name: "http"}}, spec.Scheduling)
	svc := r.buildService(tf, "frontend", 3000)
	if err := r.reconcileService(ctx, svc, tf); err != nil {
		return err
	}
	return r.reconcileDeployment(ctx, deploy, tf)
}

// =============================================================================
// Secrets
// =============================================================================

func (r *TelemetryFlowReconciler) reconcileSecrets(ctx context.Context, tf *telemetryflowv1alpha1.TelemetryFlow) error {
	secret := &corev1.Secret{
		ObjectMeta: metav1.ObjectMeta{
			Name:      fmt.Sprintf("%s-secrets", tf.Name),
			Namespace: tf.Namespace,
		},
		StringData: map[string]string{
			"DATABASE_URL":   fmt.Sprintf("postgresql://tfo:REPLACE_ME@%s-postgresql:5432/telemetryflow", tf.Name),
			"CLICKHOUSE_URL": fmt.Sprintf("clickhouse://%s-clickhouse:9000", tf.Name),
			"REDIS_URL":      fmt.Sprintf("redis://%s-redis:6379", tf.Name),
			"NATS_URL":       fmt.Sprintf("nats://%s-nats:4222", tf.Name),
		},
	}
	return r.reconcileSecret(ctx, secret, tf)
}

// =============================================================================
// Reconcile helpers (create-or-update for all resource types)
// =============================================================================

func (r *TelemetryFlowReconciler) reconcileRaw(ctx context.Context, desired client.Object, owner *telemetryflowv1alpha1.TelemetryFlow) error {
	logger := log.FromContext(ctx)
	if err := controllerutil.SetControllerReference(owner, desired, r.Scheme); err != nil {
		return err
	}

	key := types.NamespacedName{Name: desired.GetName(), Namespace: desired.GetNamespace()}
	existing := desired.DeepCopyObject().(client.Object)
	err := r.Get(ctx, key, existing)
	if err != nil && errors.IsNotFound(err) {
		logger.Info("Creating resource", "kind", desired.GetObjectKind().GroupVersionKind().Kind, "name", desired.GetName())
		return r.Create(ctx, desired)
	}
	if err != nil {
		return err
	}

	existing.SetAnnotations(desired.GetAnnotations())
	existing.SetLabels(desired.GetLabels())
	logger.Info("Updating resource", "kind", desired.GetObjectKind().GroupVersionKind().Kind, "name", desired.GetName())
	return r.Update(ctx, existing)
}

func (r *TelemetryFlowReconciler) reconcileStatefulSet(ctx context.Context, desired *appsv1.StatefulSet, owner *telemetryflowv1alpha1.TelemetryFlow) error {
	logger := log.FromContext(ctx)
	if err := controllerutil.SetControllerReference(owner, desired, r.Scheme); err != nil {
		return err
	}

	existing := &appsv1.StatefulSet{}
	err := r.Get(ctx, types.NamespacedName{Name: desired.Name, Namespace: desired.Namespace}, existing)
	if err != nil && errors.IsNotFound(err) {
		logger.Info("Creating StatefulSet", "name", desired.Name)
		return r.Create(ctx, desired)
	}
	if err != nil {
		return err
	}

	existing.Spec.Replicas = desired.Spec.Replicas
	existing.Spec.Template = desired.Spec.Template
	logger.Info("Updating StatefulSet", "name", desired.Name)
	return r.Update(ctx, existing)
}

func (r *TelemetryFlowReconciler) reconcileDeployment(ctx context.Context, desired *appsv1.Deployment, owner *telemetryflowv1alpha1.TelemetryFlow) error {
	logger := log.FromContext(ctx)
	if err := controllerutil.SetControllerReference(owner, desired, r.Scheme); err != nil {
		return err
	}

	existing := &appsv1.Deployment{}
	err := r.Get(ctx, types.NamespacedName{Name: desired.Name, Namespace: desired.Namespace}, existing)
	if err != nil && errors.IsNotFound(err) {
		logger.Info("Creating Deployment", "name", desired.Name)
		return r.Create(ctx, desired)
	}
	if err != nil {
		return err
	}

	existing.Spec.Replicas = desired.Spec.Replicas
	existing.Spec.Template = desired.Spec.Template
	logger.Info("Updating Deployment", "name", desired.Name)
	return r.Update(ctx, existing)
}

func (r *TelemetryFlowReconciler) reconcileDaemonSet(ctx context.Context, desired *appsv1.DaemonSet, owner *telemetryflowv1alpha1.TelemetryFlow) error {
	logger := log.FromContext(ctx)
	if err := controllerutil.SetControllerReference(owner, desired, r.Scheme); err != nil {
		return err
	}

	existing := &appsv1.DaemonSet{}
	err := r.Get(ctx, types.NamespacedName{Name: desired.Name, Namespace: desired.Namespace}, existing)
	if err != nil && errors.IsNotFound(err) {
		logger.Info("Creating DaemonSet", "name", desired.Name)
		return r.Create(ctx, desired)
	}
	if err != nil {
		return err
	}

	existing.Spec.Template = desired.Spec.Template
	logger.Info("Updating DaemonSet", "name", desired.Name)
	return r.Update(ctx, existing)
}

func (r *TelemetryFlowReconciler) reconcileService(ctx context.Context, desired *corev1.Service, owner *telemetryflowv1alpha1.TelemetryFlow) error {
	logger := log.FromContext(ctx)
	if err := controllerutil.SetControllerReference(owner, desired, r.Scheme); err != nil {
		return err
	}

	existing := &corev1.Service{}
	err := r.Get(ctx, types.NamespacedName{Name: desired.Name, Namespace: desired.Namespace}, existing)
	if err != nil && errors.IsNotFound(err) {
		logger.Info("Creating Service", "name", desired.Name)
		return r.Create(ctx, desired)
	}
	if err != nil {
		return err
	}

	existing.Spec.Ports = desired.Spec.Ports
	existing.Spec.Selector = desired.Spec.Selector
	logger.Info("Updating Service", "name", desired.Name)
	return r.Update(ctx, existing)
}

func (r *TelemetryFlowReconciler) reconcileConfigMap(ctx context.Context, desired *corev1.ConfigMap, owner *telemetryflowv1alpha1.TelemetryFlow) error {
	logger := log.FromContext(ctx)
	if err := controllerutil.SetControllerReference(owner, desired, r.Scheme); err != nil {
		return err
	}

	existing := &corev1.ConfigMap{}
	err := r.Get(ctx, types.NamespacedName{Name: desired.Name, Namespace: desired.Namespace}, existing)
	if err != nil && errors.IsNotFound(err) {
		logger.Info("Creating ConfigMap", "name", desired.Name)
		return r.Create(ctx, desired)
	}
	if err != nil {
		return err
	}

	existing.Data = desired.Data
	logger.Info("Updating ConfigMap", "name", desired.Name)
	return r.Update(ctx, existing)
}

func (r *TelemetryFlowReconciler) reconcileSecret(ctx context.Context, desired *corev1.Secret, owner *telemetryflowv1alpha1.TelemetryFlow) error {
	logger := log.FromContext(ctx)
	if err := controllerutil.SetControllerReference(owner, desired, r.Scheme); err != nil {
		return err
	}

	existing := &corev1.Secret{}
	err := r.Get(ctx, types.NamespacedName{Name: desired.Name, Namespace: desired.Namespace}, existing)
	if err != nil && errors.IsNotFound(err) {
		logger.Info("Creating Secret", "name", desired.Name)
		return r.Create(ctx, desired)
	}
	if err != nil {
		return err
	}

	existing.StringData = desired.StringData
	logger.Info("Updating Secret", "name", desired.Name)
	return r.Update(ctx, existing)
}

// =============================================================================
// Builders
// =============================================================================

func (r *TelemetryFlowReconciler) buildStatefulSet(tf *telemetryflowv1alpha1.TelemetryFlow, component, image string, replicas int32, resources *telemetryflowv1alpha1.ResourceSpec, persistence *telemetryflowv1alpha1.PersistenceSpec, ports []corev1.ContainerPort) *appsv1.StatefulSet {
	return r.buildStatefulSetFull(tf, component, image, replicas, resources, persistence, ports, telemetryflowv1alpha1.SchedulingSpec{})
}

func (r *TelemetryFlowReconciler) buildStatefulSetFull(tf *telemetryflowv1alpha1.TelemetryFlow, component, image string, replicas int32, resources *telemetryflowv1alpha1.ResourceSpec, persistence *telemetryflowv1alpha1.PersistenceSpec, ports []corev1.ContainerPort, scheduling telemetryflowv1alpha1.SchedulingSpec) *appsv1.StatefulSet {
	labels := r.labelsForComponent(tf.Name, component)
	sts := &appsv1.StatefulSet{
		ObjectMeta: metav1.ObjectMeta{
			Name: fmt.Sprintf("%s-%s", tf.Name, component), Namespace: tf.Namespace, Labels: labels,
		},
		Spec: appsv1.StatefulSetSpec{
			ServiceName: fmt.Sprintf("%s-%s", tf.Name, component),
			Replicas:    &replicas,
			Selector:    &metav1.LabelSelector{MatchLabels: labels},
			Template: corev1.PodTemplateSpec{
				ObjectMeta: metav1.ObjectMeta{Labels: labels},
				Spec: corev1.PodSpec{
					Containers: []corev1.Container{{
						Name: component, Image: image, Ports: ports,
						Resources: r.buildResourceRequirements(resources),
					}},
				},
			},
		},
	}

	r.applyScheduling(&sts.Spec.Template.Spec, scheduling)

	if persistence != nil && persistence.Enabled {
		pvc := corev1.PersistentVolumeClaim{
			ObjectMeta: metav1.ObjectMeta{Name: "data"},
			Spec: corev1.PersistentVolumeClaimSpec{
				AccessModes: []corev1.PersistentVolumeAccessMode{corev1.ReadWriteOnce},
				Resources: corev1.VolumeResourceRequirements{
					Requests: corev1.ResourceList{corev1.ResourceStorage: resource.MustParse(persistence.Size)},
				},
			},
		}
		if persistence.StorageClass != "" {
			pvc.Spec.StorageClassName = &persistence.StorageClass
		}
		sts.Spec.VolumeClaimTemplates = []corev1.PersistentVolumeClaim{pvc}
	}

	return sts
}

func (r *TelemetryFlowReconciler) buildStatefulSetWithArgs(tf *telemetryflowv1alpha1.TelemetryFlow, component, image string, replicas int32, resources *telemetryflowv1alpha1.ResourceSpec, persistence *telemetryflowv1alpha1.PersistenceSpec, ports []corev1.ContainerPort, args []string) *appsv1.StatefulSet {
	sts := r.buildStatefulSet(tf, component, image, replicas, resources, persistence, ports)
	sts.Spec.Template.Spec.Containers[0].Args = args
	return sts
}

func (r *TelemetryFlowReconciler) buildDeployment(tf *telemetryflowv1alpha1.TelemetryFlow, component, image string, replicas int32, resources *telemetryflowv1alpha1.ResourceSpec, ports []corev1.ContainerPort) *appsv1.Deployment {
	return r.buildDeploymentFull(tf, component, image, replicas, resources, ports, telemetryflowv1alpha1.SchedulingSpec{})
}

func (r *TelemetryFlowReconciler) buildDeploymentFull(tf *telemetryflowv1alpha1.TelemetryFlow, component, image string, replicas int32, resources *telemetryflowv1alpha1.ResourceSpec, ports []corev1.ContainerPort, scheduling telemetryflowv1alpha1.SchedulingSpec) *appsv1.Deployment {
	labels := r.labelsForComponent(tf.Name, component)
	deploy := &appsv1.Deployment{
		ObjectMeta: metav1.ObjectMeta{
			Name: fmt.Sprintf("%s-%s", tf.Name, component), Namespace: tf.Namespace, Labels: labels,
		},
		Spec: appsv1.DeploymentSpec{
			Replicas: &replicas,
			Selector: &metav1.LabelSelector{MatchLabels: labels},
			Template: corev1.PodTemplateSpec{
				ObjectMeta: metav1.ObjectMeta{Labels: labels},
				Spec: corev1.PodSpec{
					Containers: []corev1.Container{{
						Name: component, Image: image, Ports: ports,
						Resources: r.buildResourceRequirements(resources),
					}},
				},
			},
		},
	}
	r.applyScheduling(&deploy.Spec.Template.Spec, scheduling)
	return deploy
}

func (r *TelemetryFlowReconciler) buildService(tf *telemetryflowv1alpha1.TelemetryFlow, component string, port int32) *corev1.Service {
	return r.buildServiceFull(tf, component, port, nil, "")
}

func (r *TelemetryFlowReconciler) buildServiceFull(tf *telemetryflowv1alpha1.TelemetryFlow, component string, port int32, annotations map[string]string, svcType string) *corev1.Service {
	labels := r.labelsForComponent(tf.Name, component)
	svc := &corev1.Service{
		ObjectMeta: metav1.ObjectMeta{
			Name: fmt.Sprintf("%s-%s", tf.Name, component), Namespace: tf.Namespace, Labels: labels,
		},
		Spec: corev1.ServiceSpec{
			Selector: labels,
			Ports: []corev1.ServicePort{{
				Port: port, TargetPort: intstr.FromInt(int(port)), Protocol: corev1.ProtocolTCP, Name: component,
			}},
		},
	}
	if annotations != nil {
		svc.Annotations = annotations
	}
	if svcType != "" {
		svc.Spec.Type = corev1.ServiceType(svcType)
	}
	return svc
}

func (r *TelemetryFlowReconciler) buildMultiPortService(tf *telemetryflowv1alpha1.TelemetryFlow, component string, ports []corev1.ServicePort) *corev1.Service {
	return r.buildMultiPortServiceFull(tf, component, ports, nil, "")
}

func (r *TelemetryFlowReconciler) buildMultiPortServiceFull(tf *telemetryflowv1alpha1.TelemetryFlow, component string, ports []corev1.ServicePort, annotations map[string]string, svcType string) *corev1.Service {
	labels := r.labelsForComponent(tf.Name, component)
	svc := &corev1.Service{
		ObjectMeta: metav1.ObjectMeta{
			Name: fmt.Sprintf("%s-%s", tf.Name, component), Namespace: tf.Namespace, Labels: labels,
		},
		Spec: corev1.ServiceSpec{Selector: labels, Ports: ports},
	}
	if annotations != nil {
		svc.Annotations = annotations
	}
	if svcType != "" {
		svc.Spec.Type = corev1.ServiceType(svcType)
	}
	return svc
}

func (r *TelemetryFlowReconciler) buildCollectorConfigMap(tf *telemetryflowv1alpha1.TelemetryFlow, config string) *corev1.ConfigMap {
	return &corev1.ConfigMap{
		ObjectMeta: metav1.ObjectMeta{
			Name: fmt.Sprintf("%s-collector-config", tf.Name), Namespace: tf.Namespace,
		},
		Data: map[string]string{"tfo-collector.yaml": config},
	}
}

func (r *TelemetryFlowReconciler) buildAgentNodeConfigMap(tf *telemetryflowv1alpha1.TelemetryFlow, config string) *corev1.ConfigMap {
	return &corev1.ConfigMap{
		ObjectMeta: metav1.ObjectMeta{
			Name: fmt.Sprintf("%s-agent-node-config", tf.Name), Namespace: tf.Namespace,
		},
		Data: map[string]string{"tfo-agent.yaml": config},
	}
}

func (r *TelemetryFlowReconciler) buildAgentK8sConfigMap(tf *telemetryflowv1alpha1.TelemetryFlow, config string) *corev1.ConfigMap {
	return &corev1.ConfigMap{
		ObjectMeta: metav1.ObjectMeta{
			Name: fmt.Sprintf("%s-agent-k8s-config", tf.Name), Namespace: tf.Namespace,
		},
		Data: map[string]string{"tfo-agent.yaml": config},
	}
}

// =============================================================================
// Env builders
// =============================================================================

func (r *TelemetryFlowReconciler) buildCollectorEnv(tf *telemetryflowv1alpha1.TelemetryFlow, spec telemetryflowv1alpha1.CollectorSpec) []corev1.EnvVar {
	env := []corev1.EnvVar{
		{Name: "TELEMETRYFLOW_ENDPOINT", Value: fmt.Sprintf("http://%s-backend:8080/api/v2", tf.Name)},
		{Name: "LOG_LEVEL", Value: "info"},
		{Name: "LOG_FORMAT", Value: "json"},
		{Name: "OTLP_GRPC_PORT", Value: "4317"},
		{Name: "OTLP_HTTP_PORT", Value: "4318"},
		{Name: "METRICS_PORT", Value: "8888"},
		{Name: "PROMETHEUS_EXPORTER_PORT", Value: "8889"},
		{Name: "HEALTH_PORT", Value: "13133"},
		{Name: "BATCH_SIZE", Value: "8192"},
		{Name: "BATCH_TIMEOUT", Value: "200ms"},
		{Name: "QUEUE_ENABLED", Value: "true"},
		{Name: "QUEUE_PATH", Value: "/var/lib/tfo-collector/queue"},
		{Name: "QUEUE_MAX_SIZE_MB", Value: "500"},
		{Name: "POD_NAME", ValueFrom: &corev1.EnvVarSource{FieldRef: &corev1.ObjectFieldSelector{FieldPath: "metadata.name"}}},
		{Name: "POD_NAMESPACE", ValueFrom: &corev1.EnvVarSource{FieldRef: &corev1.ObjectFieldSelector{FieldPath: "metadata.namespace"}}},
		{Name: "NODE_NAME", ValueFrom: &corev1.EnvVarSource{FieldRef: &corev1.ObjectFieldSelector{FieldPath: "spec.nodeName"}}},
	}
	for _, e := range spec.Env {
		env = append(env, corev1.EnvVar{Name: e.Name, Value: e.Value})
	}
	return env
}

func (r *TelemetryFlowReconciler) buildAgentNodeEnv(tf *telemetryflowv1alpha1.TelemetryFlow) []corev1.EnvVar {
	env := []corev1.EnvVar{
		{Name: "TELEMETRYFLOW_ENDPOINT", Value: fmt.Sprintf("http://%s-backend:8080/api/v2", tf.Name)},
		{Name: "HOST_PROC", Value: "/host/proc"},
		{Name: "HOST_ETC", Value: "/host/root/etc"},
		{Name: "HOST_SYS", Value: "/host/sys"},
		{Name: "HOST_VAR", Value: "/host/root/var"},
		{Name: "HOST_RUN", Value: "/host/root/run"},
		{Name: "TELEMETRYFLOW_HOST_ROOT", Value: "/host/root"},
		{Name: "TELEMETRYFLOW_NODE_EXPORTER_ENABLED", Value: "true"},
		{Name: "TELEMETRYFLOW_K8S_ENABLED", Value: "false"},
		{Name: "TELEMETRYFLOW_PROMETHEUS_ENABLED", Value: "true"},
		{Name: "LOG_LEVEL", Value: "info"},
		{Name: "LOG_FORMAT", Value: "json"},
		{Name: "NODE_NAME", ValueFrom: &corev1.EnvVarSource{FieldRef: &corev1.ObjectFieldSelector{FieldPath: "spec.nodeName"}}},
		{Name: "POD_NAME", ValueFrom: &corev1.EnvVarSource{FieldRef: &corev1.ObjectFieldSelector{FieldPath: "metadata.name"}}},
		{Name: "POD_NAMESPACE", ValueFrom: &corev1.EnvVarSource{FieldRef: &corev1.ObjectFieldSelector{FieldPath: "metadata.namespace"}}},
		{Name: "POD_IP", ValueFrom: &corev1.EnvVarSource{FieldRef: &corev1.ObjectFieldSelector{FieldPath: "status.podIP"}}},
	}
	for _, e := range tf.Spec.Agent.Env {
		env = append(env, corev1.EnvVar{Name: e.Name, Value: e.Value})
	}
	return env
}

func (r *TelemetryFlowReconciler) buildAgentK8sEnv(tf *telemetryflowv1alpha1.TelemetryFlow) []corev1.EnvVar {
	env := []corev1.EnvVar{
		{Name: "TELEMETRYFLOW_ENDPOINT", Value: fmt.Sprintf("http://%s-backend:8080/api/v2", tf.Name)},
		{Name: "TELEMETRYFLOW_NODE_EXPORTER_ENABLED", Value: "false"},
		{Name: "TELEMETRYFLOW_K8S_ENABLED", Value: "true"},
		{Name: "TELEMETRYFLOW_PROMETHEUS_ENABLED", Value: "true"},
		{Name: "LOG_LEVEL", Value: "info"},
		{Name: "LOG_FORMAT", Value: "json"},
		{Name: "ENVIRONMENT", Value: "production"},
		{Name: "NODE_NAME", ValueFrom: &corev1.EnvVarSource{FieldRef: &corev1.ObjectFieldSelector{FieldPath: "spec.nodeName"}}},
		{Name: "POD_NAME", ValueFrom: &corev1.EnvVarSource{FieldRef: &corev1.ObjectFieldSelector{FieldPath: "metadata.name"}}},
		{Name: "POD_NAMESPACE", ValueFrom: &corev1.EnvVarSource{FieldRef: &corev1.ObjectFieldSelector{FieldPath: "metadata.namespace"}}},
	}
	for _, e := range tf.Spec.Agent.Env {
		env = append(env, corev1.EnvVar{Name: e.Name, Value: e.Value})
	}
	return env
}

// =============================================================================
// Security context helpers
// =============================================================================

func (r *TelemetryFlowReconciler) collectorSecurityContext(spec telemetryflowv1alpha1.SecurityContextSpec) *corev1.PodSecurityContext {
	truePtr := true
	return &corev1.PodSecurityContext{
		RunAsNonRoot:   boolPtr(spec.RunAsNonRoot, &truePtr),
		SeccompProfile: seccompProfile(spec.SeccompProfileType),
	}
}

// =============================================================================
// Generic helpers
// =============================================================================

func (r *TelemetryFlowReconciler) labelsForComponent(name, component string) map[string]string {
	return map[string]string{
		"app.kubernetes.io/name":       "telemetryflow",
		"app.kubernetes.io/instance":   name,
		"app.kubernetes.io/component":  component,
		"app.kubernetes.io/managed-by": "telemetryflow-operator",
	}
}

func (r *TelemetryFlowReconciler) setStatusCondition(tf *telemetryflowv1alpha1.TelemetryFlow, condition metav1.Condition) {
	condition.LastTransitionTime = metav1.Now()
	for i, c := range tf.Status.Conditions {
		if c.Type == condition.Type {
			tf.Status.Conditions[i] = condition
			return
		}
	}
	tf.Status.Conditions = append(tf.Status.Conditions, condition)
}

func (r *TelemetryFlowReconciler) buildResourceRequirements(spec *telemetryflowv1alpha1.ResourceSpec) corev1.ResourceRequirements {
	if spec == nil {
		return corev1.ResourceRequirements{}
	}
	reqs := corev1.ResourceRequirements{}
	if spec.Requests.CPU != "" || spec.Requests.Memory != "" {
		reqs.Requests = corev1.ResourceList{}
		if spec.Requests.CPU != "" {
			reqs.Requests[corev1.ResourceCPU] = resource.MustParse(spec.Requests.CPU)
		}
		if spec.Requests.Memory != "" {
			reqs.Requests[corev1.ResourceMemory] = resource.MustParse(spec.Requests.Memory)
		}
	}
	if spec.Limits.CPU != "" || spec.Limits.Memory != "" {
		reqs.Limits = corev1.ResourceList{}
		if spec.Limits.CPU != "" {
			reqs.Limits[corev1.ResourceCPU] = resource.MustParse(spec.Limits.CPU)
		}
		if spec.Limits.Memory != "" {
			reqs.Limits[corev1.ResourceMemory] = resource.MustParse(spec.Limits.Memory)
		}
	}
	return reqs
}

func convertPorts(ports []telemetryflowv1alpha1.ContainerPortSpec) []corev1.ContainerPort {
	result := make([]corev1.ContainerPort, 0, len(ports))
	for _, p := range ports {
		proto := corev1.ProtocolTCP
		if p.Protocol != "" {
			proto = corev1.Protocol(p.Protocol)
		}
		result = append(result, corev1.ContainerPort{ContainerPort: p.ContainerPort, Name: p.Name, Protocol: proto})
	}
	return result
}

func convertServicePorts(ports []telemetryflowv1alpha1.ContainerPortSpec) []corev1.ServicePort {
	result := make([]corev1.ServicePort, 0, len(ports))
	for _, p := range ports {
		result = append(result, corev1.ServicePort{
			Port: p.ContainerPort, TargetPort: intstr.FromInt(int(p.ContainerPort)),
			Protocol: corev1.ProtocolTCP, Name: p.Name,
		})
	}
	return result
}

func resourceQuantity(s string) *resource.Quantity {
	q := resource.MustParse(s)
	return &q
}

func int64Ptr(i int64) *int64 { return &i }
func boolPtr(b *bool, def *bool) *bool {
	if b != nil {
		return b
	}
	return def
}
func seccompProfile(t string) *corev1.SeccompProfile {
	if t == "" {
		t = "RuntimeDefault"
	}
	return &corev1.SeccompProfile{Type: corev1.SeccompProfileType(t)}
}

// =============================================================================
// Scheduling / Service helpers
// =============================================================================

// applyScheduling maps the EKS scheduling knobs (nodeSelector, tolerations,
// topologySpreadConstraints) onto a PodSpec. It is a no-op when the spec is empty.
func (r *TelemetryFlowReconciler) applyScheduling(pod *corev1.PodSpec, s telemetryflowv1alpha1.SchedulingSpec) {
	if len(s.NodeSelector) > 0 {
		pod.NodeSelector = s.NodeSelector
	}
	if len(s.Tolerations) > 0 {
		for _, t := range s.Tolerations {
			tol := corev1.Toleration{
				Key: t.Key, Operator: corev1.TolerationOperator(t.Operator),
				Value: t.Value, Effect: corev1.TaintEffect(t.Effect),
			}
			if t.TolerationSeconds != nil {
				sec := *t.TolerationSeconds
				tol.TolerationSeconds = &sec
			}
			pod.Tolerations = append(pod.Tolerations, tol)
		}
	}
	for _, tsc := range s.TopologySpreadConstraints {
		selector := &metav1.LabelSelector{MatchLabels: tsc.LabelSelector}
		pod.TopologySpreadConstraints = append(pod.TopologySpreadConstraints, corev1.TopologySpreadConstraint{
			MaxSkew:           tsc.MaxSkew,
			TopologyKey:       tsc.TopologyKey,
			WhenUnsatisfiable: corev1.UnsatisfiableConstraintAction(tsc.WhenUnsatisfiable),
			LabelSelector:     selector,
		})
	}
}

func serviceAnnotations(svc *telemetryflowv1alpha1.ComponentServiceSpec) map[string]string {
	if svc == nil {
		return nil
	}
	return svc.Annotations
}

func serviceType(svc *telemetryflowv1alpha1.ComponentServiceSpec) string {
	if svc == nil {
		return ""
	}
	return svc.Type
}

// =============================================================================
// Ingress (per-component: backend, frontend)
// =============================================================================

func (r *TelemetryFlowReconciler) reconcileBackendIngress(ctx context.Context, tf *telemetryflowv1alpha1.TelemetryFlow) error {
	ing := tf.Spec.Backend.Ingress
	if ing == nil || !ing.Enabled {
		return nil
	}
	return r.reconcileComponentIngress(ctx, tf, "backend", ing, 8080)
}

func (r *TelemetryFlowReconciler) reconcileFrontendIngress(ctx context.Context, tf *telemetryflowv1alpha1.TelemetryFlow) error {
	ing := tf.Spec.Frontend.Ingress
	if ing == nil || !ing.Enabled {
		return nil
	}
	return r.reconcileComponentIngress(ctx, tf, "frontend", ing, 3000)
}

func (r *TelemetryFlowReconciler) reconcileComponentIngress(ctx context.Context, tf *telemetryflowv1alpha1.TelemetryFlow, component string, spec *telemetryflowv1alpha1.ComponentIngressSpec, targetPort int) error {
	logger := log.FromContext(ctx)
	labels := r.labelsForComponent(tf.Name, component)

	pathType := networkingv1.PathTypePrefix
	paths := spec.Paths
	if len(paths) == 0 {
		paths = []string{"/"}
	}
	rules := []networkingv1.IngressRule{}
	if spec.Host != "" {
		rule := networkingv1.IngressRule{Host: spec.Host}
		rule.HTTP = &networkingv1.HTTPIngressRuleValue{}
		for _, p := range paths {
			rule.HTTP.Paths = append(rule.HTTP.Paths, networkingv1.HTTPIngressPath{
				Path:     p,
				PathType: &pathType,
				Backend: networkingv1.IngressBackend{
					Service: &networkingv1.IngressServiceBackend{
						Name: fmt.Sprintf("%s-%s", tf.Name, component),
						Port: networkingv1.ServiceBackendPort{Number: int32(targetPort)},
					},
				},
			})
		}
		rules = append(rules, rule)
	}

	tls := []networkingv1.IngressTLS{}
	if spec.TLS && spec.Host != "" {
		tlsEntry := networkingv1.IngressTLS{Hosts: []string{spec.Host}}
		if spec.TLSSecretName != "" {
			tlsEntry.SecretName = spec.TLSSecretName
		}
		tls = append(tls, tlsEntry)
	}

	ingress := &networkingv1.Ingress{
		ObjectMeta: metav1.ObjectMeta{
			Name:        fmt.Sprintf("%s-%s", tf.Name, component),
			Namespace:   tf.Namespace,
			Labels:      labels,
			Annotations: spec.Annotations,
		},
		Spec: networkingv1.IngressSpec{
			Rules: rules,
			TLS:   tls,
		},
	}
	if spec.ClassName != "" {
		ingress.Spec.IngressClassName = &spec.ClassName
	}

	if err := controllerutil.SetControllerReference(tf, ingress, r.Scheme); err != nil {
		return err
	}

	existing := &networkingv1.Ingress{}
	err := r.Get(ctx, types.NamespacedName{Name: ingress.Name, Namespace: ingress.Namespace}, existing)
	if err != nil && errors.IsNotFound(err) {
		logger.Info("Creating Ingress", "name", ingress.Name)
		return r.Create(ctx, ingress)
	}
	if err != nil {
		return err
	}

	existing.Spec.Rules = ingress.Spec.Rules
	existing.Spec.TLS = ingress.Spec.TLS
	existing.Spec.IngressClassName = ingress.Spec.IngressClassName
	existing.Annotations = ingress.Annotations
	logger.Info("Updating Ingress", "name", ingress.Name)
	return r.Update(ctx, existing)
}

// =============================================================================
// HorizontalPodAutoscaler (backend)
// =============================================================================

func (r *TelemetryFlowReconciler) reconcileBackendHPA(ctx context.Context, tf *telemetryflowv1alpha1.TelemetryFlow) error {
	logger := log.FromContext(ctx)
	as := tf.Spec.Backend.Autoscaling
	if as == nil || !as.Enabled {
		return nil
	}

	labels := r.labelsForComponent(tf.Name, "backend")
	deployName := fmt.Sprintf("%s-backend", tf.Name)

	minRep := as.MinReplicas
	if minRep == 0 {
		minRep = 1
	}
	maxRep := as.MaxReplicas
	if maxRep == 0 {
		maxRep = minRep
	}

	metrics := []autoscalingv2.MetricSpec{}
	if as.TargetCPUUtilizationPercentage > 0 {
		cpu := int32(as.TargetCPUUtilizationPercentage)
		metrics = append(metrics, autoscalingv2.MetricSpec{
			Type: autoscalingv2.ResourceMetricSourceType,
			Resource: &autoscalingv2.ResourceMetricSource{
				Name: corev1.ResourceCPU,
				Target: autoscalingv2.MetricTarget{
					Type:               autoscalingv2.UtilizationMetricType,
					AverageUtilization: &cpu,
				},
			},
		})
	}
	if as.TargetMemoryUtilizationPercentage > 0 {
		mem := int32(as.TargetMemoryUtilizationPercentage)
		metrics = append(metrics, autoscalingv2.MetricSpec{
			Type: autoscalingv2.ResourceMetricSourceType,
			Resource: &autoscalingv2.ResourceMetricSource{
				Name: corev1.ResourceMemory,
				Target: autoscalingv2.MetricTarget{
					Type:               autoscalingv2.UtilizationMetricType,
					AverageUtilization: &mem,
				},
			},
		})
	}

	hpa := &autoscalingv2.HorizontalPodAutoscaler{
		ObjectMeta: metav1.ObjectMeta{
			Name:      deployName,
			Namespace: tf.Namespace,
			Labels:    labels,
		},
		Spec: autoscalingv2.HorizontalPodAutoscalerSpec{
			MinReplicas: &minRep,
			MaxReplicas: maxRep,
			ScaleTargetRef: autoscalingv2.CrossVersionObjectReference{
				APIVersion: "apps/v1",
				Kind:       "Deployment",
				Name:       deployName,
			},
			Metrics: metrics,
		},
	}

	if err := controllerutil.SetControllerReference(tf, hpa, r.Scheme); err != nil {
		return err
	}

	existing := &autoscalingv2.HorizontalPodAutoscaler{}
	err := r.Get(ctx, types.NamespacedName{Name: hpa.Name, Namespace: hpa.Namespace}, existing)
	if err != nil && errors.IsNotFound(err) {
		logger.Info("Creating HorizontalPodAutoscaler", "name", hpa.Name)
		return r.Create(ctx, hpa)
	}
	if err != nil {
		return err
	}

	existing.Spec = hpa.Spec
	logger.Info("Updating HorizontalPodAutoscaler", "name", hpa.Name)
	return r.Update(ctx, existing)
}

// =============================================================================
// Controller registration
// =============================================================================

func (r *TelemetryFlowReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&telemetryflowv1alpha1.TelemetryFlow{}).
		Owns(&appsv1.Deployment{}).
		Owns(&appsv1.StatefulSet{}).
		Owns(&appsv1.DaemonSet{}).
		Owns(&corev1.Service{}).
		Owns(&corev1.ConfigMap{}).
		Owns(&corev1.Secret{}).
		Owns(&corev1.ServiceAccount{}).
		Owns(&rbacv1.ClusterRole{}).
		Owns(&rbacv1.ClusterRoleBinding{}).
		Owns(&networkingv1.Ingress{}).
		Owns(&autoscalingv2.HorizontalPodAutoscaler{}).
		Complete(r)
}
