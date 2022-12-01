kubectl apply -f ../kubernetes

kubectl set image deployment deployments/frontend-page website-visits=devopslearnerboy/multi-server:$GITHUB_SHA