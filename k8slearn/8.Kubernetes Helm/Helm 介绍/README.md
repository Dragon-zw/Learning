# 定制 Helm 部署

```sh
➜ cat config.yaml
mysqlUser:
  user0
mysqlPassword: user0pwd
mysqlDatabase: user0db
persistence:
  enabled: false
  
➜ helm install -f config.yaml mysql stable/mysql
WARNING: This chart is deprecated
NAME: mysql
LAST DEPLOYED: Thu Oct 30 14:35:31 2025
NAMESPACE: default
STATUS: deployed
REVISION: 1
NOTES:
MySQL can be accessed via port 3306 on the following DNS name from within your cluster:
mysql.default.svc.cluster.local

To get your root password run:

    MYSQL_ROOT_PASSWORD=$(kubectl get secret --namespace default mysql -o jsonpath="{.data.mysql-root-password}" | base64 --decode; echo)

To connect to your database:

1. Run an Ubuntu pod that you can use as a client:

    kubectl run -i --tty ubuntu --image=ubuntu:16.04 --restart=Never -- bash -il

2. Install the mysql client:

    $ apt-get update && apt-get install mysql-client -y

3. Connect using the mysql cli, then provide your password:
    $ mysql -h mysql -p

To connect to your database directly from outside the K8s cluster:
    MYSQL_HOST=127.0.0.1
    MYSQL_PORT=3306

    # Execute the following command to route the connection:
    kubectl port-forward svc/mysql 3306

    mysql -h ${MYSQL_HOST} -P${MYSQL_PORT} -u root -p${MYSQL_ROOT_PASSWORD}
```

# Helm Repo 可以添加的 URL

```sh
$ helm repo list 
NAME                    URL                                                       
jenkinsci               https://charts.jenkins.io/                                
jumpserver              https://jumpserver.github.io/helm-charts                  
bitnami                 https://charts.bitnami.com/bitnami                        
aliyunstable            https://kubernetes.oss-cn-hangzhou.aliyuncs.com/charts    
azure                   http://mirror.azure.cn/kubernetes/charts                  
stable                  https://charts.helm.sh/stable                             
gitlab                  https://charts.gitlab.io                                  
kiwigrid                https://kiwigrid.github.io                                
saleor                  https://k.github.io/saleor-helm                           
elastic                 https://helm.elastic.co                                   
harbor                  https://helm.goharbor.io                                  
reactiveops-stable      https://charts.reactiveops.com/stable                     
buttahtoast             https://buttahtoast.github.io/helm-charts/                
bedag                   https://bedag.github.io/helm-charts/                      
grafana                 https://grafana.github.io/helm-charts                     
prometheus              https://prometheus-community.github.io/helm-charts        
meshery                 https://meshery.io/charts/                                
neuvector               https://neuvector.github.io/neuvector-helm/               
higress.io              https://higress.io/helm-charts                            
istio                   https://istio-release.storage.googleapis.com/charts       
kyverno                 https://kyverno.github.io/kyverno/                        
open-telemetry          https://open-telemetry.github.io/opentelemetry-helm-charts
koderover-chart         https://koderover.tencentcloudcr.com/chartrepo/chart      
openobserve             https://charts.openobserve.ai                             
glasskube               https://charts.glasskube.eu/                              
kuma                    https://kumahq.github.io/charts                           
kubeclarity             https://openclarity.github.io/kubeclarity                 
kubevela                https://charts.kubevela.net/core
```