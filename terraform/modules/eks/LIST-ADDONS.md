# List Addons for EKS v1.35

## Update: 2026-06

```bash
aws eks list-addons --cluster-name tfo-eks-staging \
    --output table

------------------------------
|         ListAddons         |
+----------------------------+
||          addons          ||
|+--------------------------+|
||  aws-ebs-csi-driver      ||
||  aws-efs-csi-driver      ||
||  coredns                 ||
||  eks-pod-identity-agent  ||
||  kube-proxy              ||
||  snapshot-controller     ||
||  vpc-cni                 ||
|+--------------------------+|
```

---

## Discover the latest addon versions for EKS 1.35

```bash
aws eks describe-addon-versions \
    --addon-name <addon-name> \
    --kubernetes-version 1.35 \
    --query 'addons[0].addonVersions[*].addonVersion' \
    --output table
```

| Addon                    | Latest version (default in `_eks_var.tf`) |
| ------------------------ | ----------------------------------------- |
| `aws-ebs-csi-driver`     | `v1.50.0-eksbuild.1`                      |
| `aws-efs-csi-driver`     | `v2.2.5-eksbuild.1`                       |
| `coredns`                | `v1.13.1-eksbuild.1`                      |
| `eks-pod-identity-agent` | `v1.4.0-eksbuild.1`                       |
| `kube-proxy`             | `v1.35.1-eksbuild.1`                      |
| `snapshot-controller`    | `v8.4.0-eksbuild.1`                       |
| `vpc-cni`                | `v1.21.0-eksbuild.1`                      |

> Re-run the `describe-addon-versions` command above to confirm the latest
> `eksbuild` before upgrading, and update `_eks_var.tf` accordingly.

---
