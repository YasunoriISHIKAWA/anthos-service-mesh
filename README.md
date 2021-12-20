# Anthos Service Mesh

Google Cloud プロジェクトの環境変数を定義します．
```
$ export PROJECT=$(gcloud info --format='value(config.project)')
```

## クラスタの作成

GKE クラスタの環境変数を定義します．
```
$ export CLUSTER_NAME=asm-advent2021
$ export CLUSTER_LOCATION=asia-northeast1-b
```

Google Kubernetes Engine API を有効にします．
```
$ gcloud services enable container.googleapis.com
```

GKE クラスタを作成します．
```
$ gcloud container clusters create ${CLUSTER_NAME} \
    --project=${PROJECT} \
    --zone=${CLUSTER_LOCATION} \
    --machine-type=e2-standard-4 \
    --num-nodes=2 \
    --enable-ip-alias \
    --workload-pool=${PROJECT}.svc.id.goog
```

クラスタが実行されていることを確認します．
```
$ gcloud container clusters list
NAME                LOCATION           MASTER_VERSION    MASTER_IP        MACHINE_TYPE   NODE_VERSION      NUM_NODES  STATUS
asm-advent2021      asia-northeast1-b  1.21.5-gke.1302   104.198.90.75    e2-standard-4  1.21.5-gke.1302   2          RUNNING
```

クラスタに接続します．
```
$ gcloud container clusters get-credentials ${CLUSTER_NAME} \
--project=${PROJECT} \
--zone=${CLUSTER_LOCATION}
```

kubectl の現在のコンテキストをクラスタに設定します．
```
$ kubectl config set-context ${CLUSTER_NAME}
```

## Anthos Service Meshのインストール

asmcliをダウンロードします．
```
$ mkdir -p build/.toolchain/bin/
$ curl https://storage.googleapis.com/csm-artifacts/asm/asmcli_1.11 > build/.toolchain/bin/asmcli
```

asmcliに実行権限を付与します．
```
$ chmod +x build/.toolchain/bin/asmcli
```

Anthos Service Mesh をインストールします．
```
$ ./build/.toolchain/bin/asmcli install \
    --project_id ${PROJECT} \
    --cluster_name ${CLUSTER_NAME} \
    --cluster_location ${CLUSTER_LOCATION} \
    --enable_all \
    --ca mesh_ca \
    --custom_overlay $(pwd)/deployments/asm/ingress-backendconfig-operator.yaml
```

デプロイが稼働していることを確認します．
```
$ kubectl wait --for=condition=available --timeout=600s deployment --all -n istio-system
deployment.apps/istiod-asm-1115-3 condition met
$ kubectl wait --for=condition=available --timeout=600s deployment --all -n asm-system
deployment.apps/canonical-service-controller-manager condition met
```

BackendConfigを作成します．
```
$ kubectl apply -f deployments/asm/ingress-backendconfig.yaml
```

## IP アドレス指定と DNS の設定

静的IPを作成します．
```
$ gcloud compute addresses create asm-advent2021-ingress-ip --global
```

静的IPアドレスを取得します．
```
$ export GCLB_IP=$(gcloud compute addresses describe asm-advent2021-ingress-ip --global --format=json | jq -r '.address')
$ echo ${GCLB_IP}
```

Cloud Endpointsを作成するためのyamlファイルを作成します．
```
$ cat <<EOF > deployments/asm/dns-spec.yaml
swagger: "2.0"
info:
  description: "ASM Advent2021 Cloud Endpoints DNS"
  title: "ASM Advent2021 Cloud Endpoints DNS"
  version: "1.0.0"
paths: {}
host: "asm-advent2021-frontend.endpoints.${PROJECT}.cloud.goog"
x-google-endpoints:
- name: "asm-advent2021-frontend.endpoints.${PROJECT}.cloud.goog"
  target: "${GCLB_IP}"
EOF
```

Cloud プロジェクトに dns-spec.yaml ファイルをデプロイします．
```
$ gcloud endpoints services deploy deployments/asm/dns-spec.yaml
```

## TLS 証明書をプロビジョニングする

ManagedCertificate マニフェストを managed-cert.yaml として作成します．
```
$ cat <<EOF > deployments/asm/managed-cert.yaml
apiVersion: networking.gke.io/v1beta2
kind: ManagedCertificate
metadata:
  name: gke-ingress-cert
  namespace: istio-system
spec:
  domains:
    - "asm-advent2021-frontend.endpoints.${PROJECT}.cloud.goog"
EOF
```

GKE クラスタに managed-cert.yaml ファイルをデプロイします．
```
$ kubectl apply -f deployments/asm/managed-cert.yaml
```

## 自己署名 Ingress ゲートウェイ証明書をインストールする

openssl を使用して秘密鍵と証明書を作成します．
```
$ openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
  -subj "/CN=asm-advent2021-frontend.endpoints.${PROJECT}.cloud.goog/O=Edge2Mesh Inc" \
  -keyout deployments/asm/cert/asm-advent2021-frontend.endpoints.${PROJECT}.cloud.goog.key \
  -out deployments/asm/cert/asm-advent2021-frontend.endpoints.${PROJECT}.cloud.goog.crt
```

TLS証明書secret マニフェストを edge2mesh-credential.yaml として作成します．
```
$ cat <<EOF > deployments/asm/edge2mesh-credential.yaml
apiVersion: v1
kind: Secret
metadata:
  name: edge2mesh-credential
  namespace: istio-system
type: kubernetes.io/tls
data:
  tls.crt: |
        $(base64 deployments/asm/cert/asm-advent2021-frontend.endpoints.${PROJECT}.cloud.goog.crt)
  tls.key: |
        $(base64 deployments/asm/cert/asm-advent2021-frontend.endpoints.${PROJECT}.cloud.goog.key)
EOF
```

GKE クラスタに edge2mesh-credential.yaml ファイルをデプロイします．
```
$ kubectl apply -f deployments/asm/edge2mesh-credential.yaml
```

ManagedCertificate リソースを調べて、証明書の生成の進行状況を確認します．
```
$ kubectl describe managedcertificate gke-ingress-cert -n istio-system
Name:         gke-ingress-cert
Namespace:    istio-system
Labels:       <none>
Annotations:  <none>
API Version:  networking.gke.io/v1
Kind:         ManagedCertificate
Metadata:
  Creation Timestamp:  2021-12-16T02:36:38Z
  Generation:          2
  Managed Fields:
    API Version:  networking.gke.io/v1beta2
    Fields Type:  FieldsV1
    fieldsV1:
      f:metadata:
        f:annotations:
          .:
          f:kubectl.kubernetes.io/last-applied-configuration:
      f:spec:
        .:
        f:domains:
    Manager:      kubectl-client-side-apply
    Operation:    Update
    Time:         2021-12-16T02:36:38Z
    API Version:  networking.gke.io/v1
    Fields Type:  FieldsV1
    fieldsV1:
      f:status:
        .:
        f:certificateName:
        f:certificateStatus:
        f:domainStatus:
    Manager:         managed-certificate-controller
    Operation:       Update
    Time:            2021-12-16T02:36:41Z
  Resource Version:  27606
  UID:               8fe6f938-276b-45d8-a8ef-fccb48a25600
Spec:
  Domains:
    asm-advent2021-frontend.endpoints.YOUR_POJECT.cloud.goog
Status:
  Certificate Name:    mcrt-849158c7-5054-42d7-aa7d-aefaae17c1b1
  Certificate Status:  Provisioning
  Domain Status:
    Domain:  asm-advent2021-frontend.endpoints.YOUR_POJECT.cloud.goog
    Status:  Provisioning
Events:
  Type    Reason  Age   From                            Message
  ----    ------  ----  ----                            -------
  Normal  Create  87s   managed-certificate-controller  Create SslCertificate mcrt-849158c7-5054-42d7-aa7d-aefaae17c1b1
```
証明書の準備ができると、Certificate Status は Active になります．

```
$ kubectl apply -f deployments/asm/app-gateway.yaml

$ kubectl apply -f deployments/asm/ingress.yaml
```

## アプリケーションをデプロイする

**helm** をインストールする．
```
$ make install-helm
```

**ENV=env1** でアプリケーションを起動する．
```
$ build/.toolchain/bin/helm upgrade app-env1 deployments/helm/app \
  --set=namespace.name=env1,namespace.labels."istio\.io/rev"=$(kubectl -n istio-system get pods -l app=istiod -o=jsonpath='{.items[0].metadata.labels.istio\.io/rev}') \
  --install
```

**ENV=env2** でアプリケーションを起動する．
```
$ build/.toolchain/bin/helm upgrade app-env2 deployments/helm/app \
  --set=namespace.name=env2,namespace.labels."istio\.io/rev"=$(kubectl -n istio-system get pods -l app=istiod -o=jsonpath='{.items[0].metadata.labels.istio\.io/rev}') \
  --install
```

## gRPCurlで確認する

[gRPCurl][github.com/fullstorydev/grpcurl]を利用して動作を確認します．

gRPCurlをインストールします．
```
$ make install-grpcurl
```

headerに `env=env1` を設定してアクセスする．
```
$ ./build/.toolchain/bin/grpcurl -proto api/echo.proto -rpc-header 'env: env1' asm-advent2021-frontend.endpoints.${PROJECT}.cloud.goog:443 echo.EchoService/Call
{
  "message": "Hello World! ServerEnv:env1, ClientEnv:env1"
}
```

ログを確認する．
```
$ kubectl logs -f deployment/app -n env1
2021/12/16 05:05:59 start server. port:50051, env:env1
2021/12/16 05:47:20 client request env:env1
```

同じようにheaderに `env=env2` を設定すると `ENV=env2` で起動したアプリケーションが起動していることを確認できます．

## クリーンアップ

クラスタを削除します．
```
$ gcloud container clusters delete ${CLUSTER_NAME} \
    --project=${PROJECT} \
    --zone=${CLUSTER_LOCATION}
```

Anthosマネージドクラスタのリストを取得します．
```
$ gcloud container hub memberships list
NAME            EXTERNAL_ID
asm-advent2021  3a1d4344-82f6-4b3b-a6df-75f72478be53
```

今回作成したクラスタを削除します．
```
$ gcloud container hub memberships delete asm-advent2021
```

静的IPを削除します．
```
$ gcloud compute addresses delete asm-advent2021-ingress-ip --global
```

Cloud Endpointsを削除します．
```
$ gcloud endpoints services delete asm-advent2021-frontend.endpoints.${PROJECT}.cloud.goog
```

[//]:#(参考Start)
## 参考
- Anthos Service Mesh
  - [Anthos Service Mesh][anthos/service-mesh]
  - [エッジからメッシュへ: GKE Ingress を介したサービス メッシュ アプリケーションの公開][architecture/exposing-service-mesh-apps-through-gke-ingress]
  - [オプション機能の有効化][service-mesh/v1.7/docs/enable-optional-features]
  - [GKE への Anthos Service Mesh のインストール][service-mesh/v1.7/docs/scripted-install/gke-asm-onboard-1-7]
- Google Kubernetes Engine
  - [Ingress 機能の構成][cloud.google.com/kubernetes-engine/docs/how-to/ingress-features]
  - [外部 HTTP(S) 負荷分散での Ingress][cloud.google.com/kubernetes-engine/docs/concepts/ingress-xlb]
  - [Google マネージド SSL 証明書の使用][cloud.google.com/kubernetes-engine/docs/how-to/managed-certs]
- Network Endpoint Group
  - [NEG とは何か][google-cloud-jp/neg]
- Cloud Endpoints
  - [ESPv2 を使用した GKE 用 Cloud Endpoints のスタートガイド ][cloud.google.com/endpoints/docs/openapi/get-started-kubernetes-engine-espv2]
- Tools
  - [gRPCurl][github.com/fullstorydev/grpcurl]

[//]:#(参考End)

[//]:#(RefUrlStart)
[anthos/service-mesh]: https://cloud.google.com/anthos/service-mesh
[architecture/exposing-service-mesh-apps-through-gke-ingress]: https://cloud.google.com/architecture/exposing-service-mesh-apps-through-gke-ingress
[service-mesh/v1.7/docs/enable-optional-features]: https://cloud.google.com/service-mesh/v1.7/docs/enable-optional-features
[service-mesh/v1.7/docs/scripted-install/gke-asm-onboard-1-7]: https://cloud.google.com/service-mesh/v1.7/docs/scripted-install/gke-asm-onboard-1-7

[cloud.google.com/kubernetes-engine/docs/how-to/ingress-features]: https://cloud.google.com/kubernetes-engine/docs/how-to/ingress-features
[cloud.google.com/kubernetes-engine/docs/concepts/ingress-xlb]: https://cloud.google.com/kubernetes-engine/docs/concepts/ingress-xlb
[cloud.google.com/kubernetes-engine/docs/how-to/managed-certs]: https://cloud.google.com/kubernetes-engine/docs/how-to/managed-certs

[google-cloud-jp/neg]: https://medium.com/google-cloud-jp/neg-%E3%81%A8%E3%81%AF%E4%BD%95%E3%81%8B-cc1e2bbc979e

[cloud.google.com/endpoints/docs/openapi/get-started-kubernetes-engine-espv2]: https://cloud.google.com/endpoints/docs/openapi/get-started-kubernetes-engine-espv2

[github.com/fullstorydev/grpcurl]: https://github.com/fullstorydev/grpcurl
[//]:#(RefUrlEnd)
