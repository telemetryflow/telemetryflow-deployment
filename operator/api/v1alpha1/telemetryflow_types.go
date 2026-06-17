package v1alpha1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

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
	Create bool   `json:"create,omitempty"`
	Name   string `json:"name,omitempty"`
}

type BackendSpec struct {
	Image     string              `json:"image,omitempty"`
	Replicas  int32               `json:"replicas,omitempty"`
	Resources *ResourceSpec       `json:"resources,omitempty"`
	Ports     []ContainerPortSpec `json:"ports,omitempty"`
	Env       []EnvVar            `json:"env,omitempty"`
}

type FrontendSpec struct {
	Image     string              `json:"image,omitempty"`
	Replicas  int32               `json:"replicas,omitempty"`
	Resources *ResourceSpec       `json:"resources,omitempty"`
	Ports     []ContainerPortSpec `json:"ports,omitempty"`
	Env       []EnvVar            `json:"env,omitempty"`
}

type CollectorSpec struct {
	Image         string              `json:"image,omitempty"`
	Replicas      int32               `json:"replicas,omitempty"`
	Resources     *ResourceSpec       `json:"resources,omitempty"`
	Persistence   *PersistenceSpec    `json:"persistence,omitempty"`
	Ports         []ContainerPortSpec `json:"ports,omitempty"`
	Env           []EnvVar            `json:"env,omitempty"`
	Config        string              `json:"config,omitempty"`
	ServiceAccount ServiceAccountSpec `json:"serviceAccount,omitempty"`
	Security      SecurityContextSpec `json:"security,omitempty"`
}

type AgentNodeSpec struct {
	Enabled   bool         `json:"enabled,omitempty"`
	Image     string       `json:"image,omitempty"`
	Resources *ResourceSpec `json:"resources,omitempty"`
	Config    string       `json:"config,omitempty"`
}

type AgentK8sSpec struct {
	Enabled   bool         `json:"enabled,omitempty"`
	Image     string       `json:"image,omitempty"`
	Replicas  int32        `json:"replicas,omitempty"`
	Resources *ResourceSpec `json:"resources,omitempty"`
	Config    string       `json:"config,omitempty"`
}

type AgentSpec struct {
	Image         string              `json:"image,omitempty"`
	Enabled       bool                `json:"enabled,omitempty"`
	Resources     *ResourceSpec       `json:"resources,omitempty"`
	Ports         []ContainerPortSpec `json:"ports,omitempty"`
	Env           []EnvVar            `json:"env,omitempty"`
	Node          AgentNodeSpec       `json:"node,omitempty"`
	Kubernetes    AgentK8sSpec        `json:"kubernetes,omitempty"`
	ServiceAccount ServiceAccountSpec `json:"serviceAccount,omitempty"`
}

type DatabaseSpec struct {
	Image       string              `json:"image,omitempty"`
	Replicas    int32               `json:"replicas,omitempty"`
	Resources   *ResourceSpec       `json:"resources,omitempty"`
	Persistence *PersistenceSpec    `json:"persistence,omitempty"`
	Credentials *SecretRef          `json:"credentials,omitempty"`
	Ports       []ContainerPortSpec `json:"ports,omitempty"`
	Env         []EnvVar            `json:"env,omitempty"`
}

type RedisSpec struct {
	Image          string              `json:"image,omitempty"`
	Resources      *ResourceSpec       `json:"resources,omitempty"`
	Persistence    *PersistenceSpec    `json:"persistence,omitempty"`
	MaxMemory      string              `json:"maxMemory,omitempty"`
	EvictionPolicy string              `json:"evictionPolicy,omitempty"`
	Ports          []ContainerPortSpec `json:"ports,omitempty"`
	Env            []EnvVar            `json:"env,omitempty"`
}

type NATSSpec struct {
	Image            string              `json:"image,omitempty"`
	Resources        *ResourceSpec       `json:"resources,omitempty"`
	Persistence      *PersistenceSpec    `json:"persistence,omitempty"`
	JetStreamEnabled bool                `json:"jetStreamEnabled,omitempty"`
	Ports            []ContainerPortSpec `json:"ports,omitempty"`
	Env              []EnvVar            `json:"env,omitempty"`
}

type IngressHost struct {
	Host   string   `json:"host,omitempty"`
	Paths  []string `json:"paths,omitempty"`
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
