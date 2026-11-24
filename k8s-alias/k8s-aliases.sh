# ~/alias/k8s-alias/k8s-aliases.sh — bộ kubectl alias tinh gọn cho CKA + Production
# Nạp từ ~/.bashrc. Mặc định là profile prod (an toàn).
# Máy luyện thi: export K8S_PROFILE=cka trước khi source (hoặc đặt trong .bashrc).
# Nguyên tắc: KHÔNG alias delete/drain/cordon/scale/edit — gõ đầy đủ là ma sát có chủ đích.

command -v kubectl >/dev/null 2>&1 || return 0

# --- Lõi (cả CKA & Prod) ------------------------------------------------------
source <(kubectl completion bash)
alias k=kubectl
complete -o default -F __start_kubectl k

# Sinh manifest ở client, không đụng cluster:  k create deploy web --image=nginx $do > web.yaml
export do="--dry-run=client -o yaml"

alias kd='kubectl describe'
# Events theo thời gian (mới nhất ở cuối) — bước đầu của mọi troubleshooting
alias kev='kubectl get events --sort-by=.metadata.creationTimestamp'

# Đổi namespace mặc định của context hiện tại:  kn kube-system
kn() { kubectl config set-context --current --namespace="${1:?usage: kn <namespace>}"; }

# Pod "có vấn đề" toàn cluster: Pending/CrashLoopBackOff/ImagePull/Error hoặc Running nhưng READY thiếu.
# Bỏ qua Completed (Job xong). Có thể truyền thêm cờ, ví dụ: kbad -l app=web
kbad() {
  kubectl get pods -A --no-headers "$@" |
    awk '$4!="Completed" && ($4!="Running" || (split($3,a,"/") && a[1]!=a[2]))'
}

# Pod tạm để test DNS/Service/NetworkPolicy, tự xoá khi thoát:  ktmp  |  ktmp nicolaka/netshoot
ktmp() { kubectl run "tmp-$RANDOM" --rm -it --restart=Never --image="${1:-busybox:1.36}" -- sh; }

# --- Theo profile --------------------------------------------------------------
if [ "${K8S_PROFILE:-prod}" = "cka" ]; then
  # CHỈ dùng trong lab/thi: force-delete pod StatefulSet ở prod có thể gây split-brain.
  export now="--force --grace-period=0"
else
  # Luôn xem diff trước khi apply:  kdf app.yaml && k apply -f app.yaml
  alias kdf='kubectl diff -f'

  _k8s_where() {
    local w; w=$(kubectl config view --minify -o jsonpath='{.current-context}:{..namespace}' 2>/dev/null) || { echo "no-context"; return; }
    case "$w" in *:) w="${w}default" ;; esac
    echo "$w"
  }
  kwhere() { echo "$(_k8s_where)  (KUBECONFIG=${KUBECONFIG:-~/.kube/config})"; }

  # Prompt luôn hiển thị context:namespace để tránh chạy nhầm cluster (1 lần gọi kubectl/prompt)
  case "$PS1" in
    *_k8s_where*) ;;
    *) PS1='\[\e[33m\][$(_k8s_where)]\[\e[0m\] '"$PS1" ;;
  esac
fi
