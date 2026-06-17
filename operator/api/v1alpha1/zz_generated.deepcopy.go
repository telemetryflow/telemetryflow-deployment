package v1alpha1

import (
	"k8s.io/apimachinery/pkg/runtime"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

func (in *ResourceSpec) DeepCopy() *ResourceSpec {
	if in == nil {
		return nil
	}
	out := new(ResourceSpec)
	in.DeepCopyInto(out)
	return out
}

func (in *ResourceSpec) DeepCopyInto(out *ResourceSpec) {
	*out = *in
	out.Requests = in.Requests
	out.Limits = in.Limits
}

func (in *CoreResource) DeepCopy() *CoreResource {
	if in == nil {
		return nil
	}
	out := new(CoreResource)
	in.DeepCopyInto(out)
	return out
}

func (in *CoreResource) DeepCopyInto(out *CoreResource) {
	*out = *in
}

func (in *PersistenceSpec) DeepCopy() *PersistenceSpec {
	if in == nil {
		return nil
	}
	out := new(PersistenceSpec)
	in.DeepCopyInto(out)
	return out
}

func (in *PersistenceSpec) DeepCopyInto(out *PersistenceSpec) {
	*out = *in
}

func (in *SecretRef) DeepCopy() *SecretRef {
	if in == nil {
		return nil
	}
	out := new(SecretRef)
	in.DeepCopyInto(out)
	return out
}

func (in *SecretRef) DeepCopyInto(out *SecretRef) {
	*out = *in
}

func (in *BackendSpec) DeepCopy() *BackendSpec {
	if in == nil {
		return nil
	}
	out := new(BackendSpec)
	in.DeepCopyInto(out)
	return out
}

func (in *BackendSpec) DeepCopyInto(out *BackendSpec) {
	*out = *in
	if in.Resources != nil {
		in, out := &in.Resources, &out.Resources
		*out = new(ResourceSpec)
		(*in).DeepCopyInto(*out)
	}
}

func (in *FrontendSpec) DeepCopy() *FrontendSpec {
	if in == nil {
		return nil
	}
	out := new(FrontendSpec)
	in.DeepCopyInto(out)
	return out
}

func (in *FrontendSpec) DeepCopyInto(out *FrontendSpec) {
	*out = *in
	if in.Resources != nil {
		in, out := &in.Resources, &out.Resources
		*out = new(ResourceSpec)
		(*in).DeepCopyInto(*out)
	}
}

func (in *CollectorSpec) DeepCopy() *CollectorSpec {
	if in == nil {
		return nil
	}
	out := new(CollectorSpec)
	in.DeepCopyInto(out)
	return out
}

func (in *CollectorSpec) DeepCopyInto(out *CollectorSpec) {
	*out = *in
	if in.Resources != nil {
		in, out := &in.Resources, &out.Resources
		*out = new(ResourceSpec)
		(*in).DeepCopyInto(*out)
	}
	if in.Persistence != nil {
		in, out := &in.Persistence, &out.Persistence
		*out = new(PersistenceSpec)
		**out = **in
	}
}

func (in *AgentSpec) DeepCopy() *AgentSpec {
	if in == nil {
		return nil
	}
	out := new(AgentSpec)
	in.DeepCopyInto(out)
	return out
}

func (in *AgentSpec) DeepCopyInto(out *AgentSpec) {
	*out = *in
	if in.Resources != nil {
		in, out := &in.Resources, &out.Resources
		*out = new(ResourceSpec)
		(*in).DeepCopyInto(*out)
	}
}

func (in *DatabaseSpec) DeepCopy() *DatabaseSpec {
	if in == nil {
		return nil
	}
	out := new(DatabaseSpec)
	in.DeepCopyInto(out)
	return out
}

func (in *DatabaseSpec) DeepCopyInto(out *DatabaseSpec) {
	*out = *in
	if in.Resources != nil {
		in, out := &in.Resources, &out.Resources
		*out = new(ResourceSpec)
		(*in).DeepCopyInto(*out)
	}
	if in.Persistence != nil {
		in, out := &in.Persistence, &out.Persistence
		*out = new(PersistenceSpec)
		**out = **in
	}
	if in.Credentials != nil {
		in, out := &in.Credentials, &out.Credentials
		*out = new(SecretRef)
		**out = **in
	}
}

func (in *RedisSpec) DeepCopy() *RedisSpec {
	if in == nil {
		return nil
	}
	out := new(RedisSpec)
	in.DeepCopyInto(out)
	return out
}

func (in *RedisSpec) DeepCopyInto(out *RedisSpec) {
	*out = *in
	if in.Resources != nil {
		in, out := &in.Resources, &out.Resources
		*out = new(ResourceSpec)
		(*in).DeepCopyInto(*out)
	}
	if in.Persistence != nil {
		in, out := &in.Persistence, &out.Persistence
		*out = new(PersistenceSpec)
		**out = **in
	}
}

func (in *NATSSpec) DeepCopy() *NATSSpec {
	if in == nil {
		return nil
	}
	out := new(NATSSpec)
	in.DeepCopyInto(out)
	return out
}

func (in *NATSSpec) DeepCopyInto(out *NATSSpec) {
	*out = *in
	if in.Resources != nil {
		in, out := &in.Resources, &out.Resources
		*out = new(ResourceSpec)
		(*in).DeepCopyInto(*out)
	}
	if in.Persistence != nil {
		in, out := &in.Persistence, &out.Persistence
		*out = new(PersistenceSpec)
		**out = **in
	}
}

func (in *IngressHost) DeepCopy() *IngressHost {
	if in == nil {
		return nil
	}
	out := new(IngressHost)
	in.DeepCopyInto(out)
	return out
}

func (in *IngressHost) DeepCopyInto(out *IngressHost) {
	*out = *in
	if in.Paths != nil {
		in, out := &in.Paths, &out.Paths
		*out = make([]string, len(*in))
		copy(*out, *in)
	}
}

func (in *IngressSpec) DeepCopy() *IngressSpec {
	if in == nil {
		return nil
	}
	out := new(IngressSpec)
	in.DeepCopyInto(out)
	return out
}

func (in *IngressSpec) DeepCopyInto(out *IngressSpec) {
	*out = *in
	if in.Hosts != nil {
		in, out := &in.Hosts, &out.Hosts
		*out = make([]IngressHost, len(*in))
		for i := range *in {
			(*in)[i].DeepCopyInto(&(*out)[i])
		}
	}
}

func (in *SecretsSpec) DeepCopy() *SecretsSpec {
	if in == nil {
		return nil
	}
	out := new(SecretsSpec)
	in.DeepCopyInto(out)
	return out
}

func (in *SecretsSpec) DeepCopyInto(out *SecretsSpec) {
	*out = *in
	out.Backend = in.Backend
	out.Agent = in.Agent
	out.Database = in.Database
}

func (in *TelemetryFlowSpec) DeepCopy() *TelemetryFlowSpec {
	if in == nil {
		return nil
	}
	out := new(TelemetryFlowSpec)
	in.DeepCopyInto(out)
	return out
}

func (in *TelemetryFlowSpec) DeepCopyInto(out *TelemetryFlowSpec) {
	*out = *in
	in.Backend.DeepCopyInto(&out.Backend)
	in.Frontend.DeepCopyInto(&out.Frontend)
	in.Collector.DeepCopyInto(&out.Collector)
	in.Agent.DeepCopyInto(&out.Agent)
	in.PostgreSQL.DeepCopyInto(&out.PostgreSQL)
	in.ClickHouse.DeepCopyInto(&out.ClickHouse)
	in.Redis.DeepCopyInto(&out.Redis)
	in.BullMQRedis.DeepCopyInto(&out.BullMQRedis)
	in.NATS.DeepCopyInto(&out.NATS)
	in.Ingress.DeepCopyInto(&out.Ingress)
	in.Secrets.DeepCopyInto(&out.Secrets)
}

func (in *ComponentStatus) DeepCopy() *ComponentStatus {
	if in == nil {
		return nil
	}
	out := new(ComponentStatus)
	in.DeepCopyInto(out)
	return out
}

func (in *ComponentStatus) DeepCopyInto(out *ComponentStatus) {
	*out = *in
}

func (in *TelemetryFlowStatus) DeepCopy() *TelemetryFlowStatus {
	if in == nil {
		return nil
	}
	out := new(TelemetryFlowStatus)
	in.DeepCopyInto(out)
	return out
}

func (in *TelemetryFlowStatus) DeepCopyInto(out *TelemetryFlowStatus) {
	*out = *in
	if in.Conditions != nil {
		in, out := &in.Conditions, &out.Conditions
		*out = make([]metav1.Condition, len(*in))
		for i := range *in {
			(*in)[i].DeepCopyInto(&(*out)[i])
		}
	}
	if in.ComponentStatuses != nil {
		in, out := &in.ComponentStatuses, &out.ComponentStatuses
		*out = make(map[string]ComponentStatus, len(*in))
		for key, val := range *in {
			(*out)[key] = *val.DeepCopy()
		}
	}
}

func (in *TelemetryFlow) DeepCopy() *TelemetryFlow {
	if in == nil {
		return nil
	}
	out := new(TelemetryFlow)
	in.DeepCopyInto(out)
	return out
}

func (in *TelemetryFlow) DeepCopyInto(out *TelemetryFlow) {
	*out = *in
	out.TypeMeta = in.TypeMeta
	in.ObjectMeta.DeepCopyInto(&out.ObjectMeta)
	in.Spec.DeepCopyInto(&out.Spec)
	in.Status.DeepCopyInto(&out.Status)
}

func (in *TelemetryFlow) DeepCopyObject() runtime.Object {
	if c := in.DeepCopy(); c != nil {
		return c
	}
	return nil
}

func (in *TelemetryFlowList) DeepCopy() *TelemetryFlowList {
	if in == nil {
		return nil
	}
	out := new(TelemetryFlowList)
	in.DeepCopyInto(out)
	return out
}

func (in *TelemetryFlowList) DeepCopyInto(out *TelemetryFlowList) {
	*out = *in
	out.TypeMeta = in.TypeMeta
	in.ListMeta.DeepCopyInto(&out.ListMeta)
	if in.Items != nil {
		in, out := &in.Items, &out.Items
		*out = make([]TelemetryFlow, len(*in))
		for i := range *in {
			(*in)[i].DeepCopyInto(&(*out)[i])
		}
	}
}

func (in *TelemetryFlowList) DeepCopyObject() runtime.Object {
	if c := in.DeepCopy(); c != nil {
		return c
	}
	return nil
}
