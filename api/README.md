# API

## buf

## generate

`.proto`ファイルから以下のファイルを作成します．

- *.pb.go
- *_grpc.pb.go

`api/buf.gen.yaml`でテンプレート生成の設定を行っています．

```
# make buf-generate
```

- e.g.
    ```
    root@app-64f6668ffd-xzgnh:/app# make buf-generate
    ```

## 参考

- [buf][docs.buf.build]
- [Language Guide (proto3)][protocol-buffers/docs/proto3] 
- [Google Protocol Buffers Style Guide][protocol-buffers/docs/style]

[//]:#(参考)

[//]:#(RefUrlStart)

[docs.buf.build]: https://docs.buf.build
[protocol-buffers/docs/proto3]: https://developers.google.com/protocol-buffers/docs/proto3
[protocol-buffers/docs/style]: https://developers.google.com/protocol-buffers/docs/style

[//]:#(RefUrlEnd)
