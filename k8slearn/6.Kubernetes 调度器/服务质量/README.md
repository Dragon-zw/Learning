# Qos 解析

```sh
# 引用资源清单文件
➜ kubectl apply -f qos-demo.yaml
pod/qos-demo created

➜ kubectl get pods qos-demo -o wide
NAME       READY   STATUS    RESTARTS   AGE   IP               NODE           NOMINATED NODE   READINESS GATES
qos-demo   1/1     Running   0          20s   192.244.211.36   hkk8snode001   <none>           <none>

➜ kubectl get pods qos-demo -o yaml | grep uid
  uid: 76602608-e9c6-4a04-9a5a-8f7cb382a17e
  
➜ kubectl get pods qos-demo -o yaml | grep qosClass
  qosClass: Burstable # 不稳定的，设置了 request 和 limits 但是不相等。
```

由于该 Pod 的设置的资源 requests != limits，所以其属于 Burstable 类别的 Pod，kubelet 会在其所属 QoS 下创建 RootCgroup/system.slice/containerd.service/kubepods-burstable-pod<uid>.slice:cri-containerd:<container-id> 