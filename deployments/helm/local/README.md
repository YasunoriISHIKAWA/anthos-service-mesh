## Helm

ローカルの開発環境の作成にHelmを利用しています．

## Helmのインストール

```
$ make install-helm
```

```
$ make create-local-values
```

## helm upgrade

```
$ build/.toolchain/bin/helm upgrade app deployments/helm/local --install \
  --namespace=asm-sample \
  --create-namespace
```

## 確認

```
$ kubectl get po -n asm-sample
NAME                   READY   STATUS    RESTARTS   AGE
app-74b5d5df55-qlwls   1/1     Running   0          74s
```

## helm uninstall

```
$ build/.toolchain/bin/helm uninstall app --namespace asm-sample
```

[//]:#(参考)

## 参考

- [Helm][helm.sh]

[//]:#(参考)

[//]:#(RefUrlStart)

[helm.sh]: https://helm.sh

[//]:#(RefUrlEnd)
