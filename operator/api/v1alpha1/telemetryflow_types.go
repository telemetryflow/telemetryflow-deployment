package v1alpha1

import (
	apiextensionsv1 "k8s.io/apiextensions-apiserver/pkg/apis/apiextensions/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// =============================================================================
// Shared building blocks
// =============================================================================

type ResourceSpec struct {
	Requests CoreResource `json:"requests,omitempty"`
	Limits   CoreResource `json:"limits,omitempty"`
}

type CoreResource struct {
	CPU    string `json:"cpu,omitempty"`
	Memory string `json:"memory,omitempty"`
}

type PersistenceSpec struct {
	Enabled      bool   `json:"enabled,omitempty"`
	StorageClass string `json:"storageClass,omitempty"`
	Size         string `json:"size,omitempty"`
}

type SecretRef struct {
	Name string `json:"name,omitempty"`
}

type SecurityContextSpec struct {
	RunAsUser                *int64   `json:"runAsUser,omitempty"`
	RunAsGroup               *int64   `json:"runAsGroup,omitempty"`
	RunAsNonRoot             *bool    `json:"runAsNonRoot,omitempty"`
	ReadOnlyRootFilesystem   *bool    `json:"readOnlyRootFilesystem,omitempty"`
	AllowPrivilegeEscalation *bool    `json:"allowPrivilegeEscalation,omitempty"`
	SeccompProfileType       string   `json:"seccompProfileType,omitempty"`
	DropCapabilities         []string `json:"dropCapabilities,omitempty"`
	AddCapabilities          []string `json:"addCapabilities,omitempty"`
}

type ContainerPortSpec struct {
	ContainerPort int32  `json:"containerPort,omitempty"`
	Name          string `json:"name,omitempty"`
	Protocol      string `json:"protocol,omitempty"`
}

type EnvVar struct {
	Name  string `json:"name"`
	Value string `json:"value,omitempty"`
}

type ServiceAccountSpec struct {
	Create      bool              `json:"create,omitempty"`
	Name        string            `json:"name,omitempty"`
	Annotations map[string]string `json:"annotations,omitempty"`
}

// SchedulingSpec exposes the EKS scheduling knobs found in the helm values:
// nodeSelector, tolerations, topologySpreadConstraints, affinity.
type SchedulingSpec struct {
	NodeSelector              map[string]string              `json:"nodeSelector,omitempty"`
	Tolerations               []TolerationSpec               `json:"tolerations,omitempty"`
	TopologySpreadConstraints []TopologySpreadConstraintSpec `json:"topologySpreadConstraints,omitempty"`
	Affinity                  *AffinitySpec                  `json:"affinity,omitempty"`
}

type TolerationSpec struct {
	Key               string `json:"key,omitempty"`
	Operator          string `json:"operator,omitempty"`
	Value             string `json:"value,omitempty"`
	Effect            string `json:"effect,omitempty"`
	TolerationSeconds *int64 `json:"tolerationSeconds,omitempty"`
}

type TopologySpreadConstraintSpec struct {
	MaxSkew           int32             `json:"maxSkew,omitempty"`
	TopologyKey       string            `json:"topologyKey,omitempty"`
	WhenUnsatisfiable string            `json:"whenUnsatisfiable,omitempty"`
	LabelSelector     map[string]string `json:"labelSelector,omitempty"`
}

type AffinitySpec struct {
	NodeAffinity    *apiextensionsv1.JSON `json:"nodeAffinity,omitempty"`
	PodAffinity     *apiextensionsv1.JSON `json:"podAffinity,omitempty"`
	PodAntiAffinity *apiextensionsv1.JSON `json:"podAntiAffinity,omitempty"`
}

// ComponentServiceSpec models the per-component Service (e.g. NLB annotations).
type ComponentServiceSpec struct {
	Type        string            `json:"type,omitempty"`
	Annotations map[string]string `json:"annotations,omitempty"`
	Port        int32             `json:"port,omitempty"`
}

// ComponentIngressSpec models the per-component Ingress (backend, viz).
type ComponentIngressSpec struct {
	Enabled       bool              `json:"enabled,omitempty"`
	ClassName     string            `json:"className,omitempty"`
	Host          string            `json:"host,omitempty"`
	Annotations   map[string]string `json:"annotations,omitempty"`
	TLS           bool              `json:"tls,omitempty"`
	TLSSecretName string            `json:"tlsSecretName,omitempty"`
	Paths         []string          `json:"paths,omitempty"`
}

// AutoscalingSpec models an HPA attached to a Deployment.
type AutoscalingSpec struct {
	Enabled                           bool  `json:"enabled,omitempty"`
	MinReplicas                       int32 `json:"minReplicas,omitempty"`
	MaxReplicas                       int32 `json:"maxReplicas,omitempty"`
	TargetCPUUtilizationPercentage    int32 `json:"targetCPUUtilizationPercentage,omitempty"`
	TargetMemoryUtilizationPercentage int32 `json:"targetMemoryUtilizationPercentage,omitempty"`
}

// =============================================================================
// Component specs
// =============================================================================

type BackendSpec struct {
	Image          string                `json:"image,omitempty"`
	Replicas       int32                 `json:"replicas,omitempty"`
	Resources      *ResourceSpec         `json:"resources,omitempty"`
	Ports          []ContainerPortSpec   `json:"ports,omitempty"`
	Env            []EnvVar              `json:"env,omitempty"`
	Scheduling     SchedulingSpec        `json:"scheduling,omitempty"`
	Service        *ComponentServiceSpec `json:"service,omitempty"`
	Ingress        *ComponentIngressSpec `json:"ingress,omitempty"`
	Autoscaling    *AutoscalingSpec      `json:"autoscaling,omitempty"`
	ServiceAccount ServiceAccountSpec    `json:"serviceAccount,omitempty"`
}

type FrontendSpec struct {
	Image      string                `json:"image,omitempty"`
	Replicas   int32                 `json:"replicas,omitempty"`
	Resources  *ResourceSpec         `json:"resources,omitempty"`
	Ports      []ContainerPortSpec   `json:"ports,omitempty"`
	Env        []EnvVar              `json:"env,omitempty"`
	Scheduling SchedulingSpec        `json:"scheduling,omitempty"`
	Ingress    *ComponentIngressSpec `json:"ingress,omitempty"`
}

type CollectorSpec struct {
	Image          string                `json:"image,omitempty"`
	Replicas       int32                 `json:"replicas,omitempty"`
	Resources      *ResourceSpec         `json:"resources,omitempty"`
	Persistence    *PersistenceSpec      `json:"persistence,omitempty"`
	Ports          []ContainerPortSpec   `json:"ports,omitempty"`
	Env            []EnvVar              `json:"env,omitempty"`
	Config         string                `json:"config,omitempty"`
	Scheduling     SchedulingSpec        `json:"scheduling,omitempty"`
	Service        *ComponentServiceSpec `json:"service,omitempty"`
	ServiceAccount ServiceAccountSpec    `json:"serviceAccount,omitempty"`
	Security       SecurityContextSpec   `json:"security,omitempty"`
}

type AgentNodeSpec struct {
	Enabled    bool           `json:"enabled,omitempty"`
	Image      string         `json:"image,omitempty"`
	Resources  *ResourceSpec  `json:"resources,omitempty"`
	Config     string         `json:"config,omitempty"`
	Scheduling SchedulingSpec `json:"scheduling,omitempty"`
}

type AgentK8sSpec struct {
	Enabled    bool           `json:"enabled,omitempty"`
	Image      string         `json:"image,omitempty"`
	Replicas   int32          `json:"replicas,omitempty"`
	Resources  *ResourceSpec  `json:"resources,omitempty"`
	Config     string         `json:"config,omitempty"`
	Scheduling SchedulingSpec `json:"scheduling,omitempty"`
}

type AgentSpec struct {
	Image           string              `json:"image,omitempty"`
	Enabled         bool                `json:"enabled,omitempty"`
	ClusterProvider string              `json:"clusterProvider,omitempty"`
	Resources       *ResourceSpec       `json:"resources,omitempty"`
	Ports           []ContainerPortSpec `json:"ports,omitempty"`
	Env             []EnvVar            `json:"env,omitempty"`
	Node            AgentNodeSpec       `json:"node,omitempty"`
	Kubernetes      AgentK8sSpec        `json:"kubernetes,omitempty"`
	Scheduling      SchedulingSpec      `json:"scheduling,omitempty"`
	ServiceAccount  ServiceAccountSpec  `json:"serviceAccount,omitempty"`
}

type DatabaseSpec struct {
	Image       string              `json:"image,omitempty"`
	Replicas    int32               `json:"replicas,omitempty"`
	Resources   *ResourceSpec       `json:"resources,omitempty"`
	Persistence *PersistenceSpec    `json:"persistence,omitempty"`
	Credentials *SecretRef          `json:"credentials,omitempty"`
	Ports       []ContainerPortSpec `json:"ports,omitempty"`
	Env         []EnvVar            `json:"env,omitempty"`
	Scheduling  SchedulingSpec      `json:"scheduling,omitempty"`
}

type RedisSpec struct {
	Image          string              `json:"image,omitempty"`
	Resources      *ResourceSpec       `json:"resources,omitempty"`
	Persistence    *PersistenceSpec    `json:"persistence,omitempty"`
	MaxMemory      string              `json:"maxMemory,omitempty"`
	EvictionPolicy string              `json:"evictionPolicy,omitempty"`
	Ports          []ContainerPortSpec `json:"ports,omitempty"`
	Env            []EnvVar            `json:"env,omitempty"`
	Scheduling     SchedulingSpec      `json:"scheduling,omitempty"`
}

type NATSSpec struct {
	Image            string              `json:"image,omitempty"`
	Resources        *ResourceSpec       `json:"resources,omitempty"`
	Persistence      *PersistenceSpec    `json:"persistence,omitempty"`
	JetStreamEnabled bool                `json:"jetStreamEnabled,omitempty"`
	JetStream        *JetStreamSpec      `json:"jetstream,omitempty"`
	Ports            []ContainerPortSpec `json:"ports,omitempty"`
	Env              []EnvVar            `json:"env,omitempty"`
	Scheduling       SchedulingSpec      `json:"scheduling,omitempty"`
}

type JetStreamSpec struct {
	MaxSize   string `json:"maxSize,omitempty"`
	MaxMemory string `json:"maxMemory,omitempty"`
}

type IngressHost struct {
	Host  string   `json:"host,omitempty"`
	Paths []string `json:"paths,omitempty"`
}

type IngressSpec struct {
	Enabled    bool          `json:"enabled,omitempty"`
	ClassName  string        `json:"className,omitempty"`
	Hosts      []IngressHost `json:"hosts,omitempty"`
	TLSEnabled bool          `json:"tlsEnabled,omitempty"`
}

type SecretsSpec struct {
	Create    bool      `json:"create,omitempty"`
	Backend   SecretRef `json:"backend,omitempty"`
	Agent     SecretRef `json:"agent,omitempty"`
	Collector SecretRef `json:"collector,omitempty"`
	Database  SecretRef `json:"database,omitempty"`
}

type TelemetryFlowSpec struct {
	Version     string        `json:"version,omitempty"`
	Backend     BackendSpec   `json:"backend,omitempty"`
	Frontend    FrontendSpec  `json:"frontend,omitempty"`
	Collector   CollectorSpec `json:"collector,omitempty"`
	Agent       AgentSpec     `json:"agent,omitempty"`
	PostgreSQL  DatabaseSpec  `json:"postgresql,omitempty"`
	ClickHouse  DatabaseSpec  `json:"clickhouse,omitempty"`
	Redis       RedisSpec     `json:"redis,omitempty"`
	BullMQRedis RedisSpec     `json:"bullmqRedis,omitempty"`
	NATS        NATSSpec      `json:"nats,omitempty"`
	Ingress     IngressSpec   `json:"ingress,omitempty"`
	Secrets     SecretsSpec   `json:"secrets,omitempty"`
}

type ComponentStatus struct {
	Ready    bool   `json:"ready,omitempty"`
	Message  string `json:"message,omitempty"`
	Replicas int32  `json:"replicas,omitempty"`
}

type TelemetryFlowStatus struct {
	Conditions         []metav1.Condition         `json:"conditions,omitempty"`
	Phase              string                     `json:"phase,omitempty"`
	Ready              bool                       `json:"ready,omitempty"`
	Message            string                     `json:"message,omitempty"`
	ObservedGeneration int64                      `json:"observedGeneration,omitempty"`
	ComponentStatuses  map[string]ComponentStatus `json:"componentStatuses,omitempty"`
}

//+kubebuilder:object:root=true
//+kubebuilder:subresource:status
//+kubebuilder:printcolumn:name="Phase",type="string",JSONPath=".status.phase"
//+kubebuilder:printcolumn:name="Ready",type="boolean",JSONPath=".status.ready"
//+kubebuilder:printcolumn:name="Version",type="string",JSONPath=".spec.version"
//+kubebuilder:printcolumn:name="Age",type="date",JSONPath=".metadata.creationTimestamp"

type TelemetryFlow struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   TelemetryFlowSpec   `json:"spec,omitempty"`
	Status TelemetryFlowStatus `json:"status,omitempty"`
}

//+kubebuilder:object:root=true

type TelemetryFlowList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []TelemetryFlow `json:"items"`
}

func init() {
	SchemeBuilder.Register(&TelemetryFlow{}, &TelemetryFlowList{})
}
