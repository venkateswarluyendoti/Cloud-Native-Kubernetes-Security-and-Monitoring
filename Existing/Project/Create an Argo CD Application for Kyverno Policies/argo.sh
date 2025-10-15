Apply:
-------

kubectl apply -f argo-kyverno-app.yaml


 Verify Deployment:
 -------------------
 kubectl get applications -n argocd

To check if policies are enforced:
----------------------------------
 kubectl get cpol


 Automate Policy Syncing
 -------------------------
 Argo CD automatically syncs the policies whenever you push a change to GitHub. If a new policy is added or updated in the repo, Argo CD will apply it automatically because of:

  syncPolicy:
    automated:
      prune: true
      selfHeal: true


✅ prune → Deletes removed policies from the cluster
✅ selfHeal → Fixes any manual changes that deviate from GitHub      

Kyverno policies are stored & managed in GitHub
✅ Argo CD automatically syncs and enforces policies
✅ Any updates pushed to GitHub reflect immediately in Kubernetes

This is GitOps for Policy Management using Kyverno + Argo CD! 



