```sh
➜ kubectl config current-context
kubernetes-admin@kubernetes

# 切换到默认的命名空间
➜ kubectl config set-context kubernetes-admin@kubernetes --namespace=opa
Context "kubernetes-admin@kubernetes" modified.

➜ kubectl get pods
No resources found in opa namespace.
```