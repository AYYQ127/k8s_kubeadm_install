# dashboard安装

### 注意事项

```bash
# 如果安装版本为v2.7.0或以前版本，则不需要cert-manager 和 nginx-ingress-controller，
# 但是需要修改yaml文件的Service.kubernetes-dashboard.spec.ports
# 在安装前自行修改端口
wget https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

---
kind: Service
apiVersion: v1
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
spec:
  ports:
    - port: 443
      targetPort: 8443
      nodePoart: 30443    # 定义nodePort访问端口
  selector:
    k8s-app: kubernetes-dashboard
  type: NodePort          # 设置端口类型，默认为ClusterIP
---
```


