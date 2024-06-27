for resource in $(kubectl api-resources --verbs=list --namespaced -o name); do
    for name in $(kubectl get $resource -n $NAMESPACE -o json | jq -r '.items[] | select(.metadata.finalizers) | .metadata.name'); do
        echo "Patching $resource $name to remove finalizers..."
        kubectl patch $resource $name -n $NAMESPACE -p '{"metadata":{"finalizers":[]}}' --type=merge
    done
done