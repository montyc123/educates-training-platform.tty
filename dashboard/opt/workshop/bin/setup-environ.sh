# Try and work out the correct version of the command line tools to use
# if not explicitly specified in environment. This assumes you will be
# using the same cluster the deployment is to.

KUBERNETES_SERVER=$KUBERNETES_PORT_443_TCP_ADDR:$KUBERNETES_PORT_443_TCP_PORT

if [ "$KUBERNETES_SERVER" != ":" ]; then
    if [ -z "$KUBECTL_VERSION" ]; then
        KUBECTL_VERSION=`(curl -s -k https://$KUBERNETES_SERVER/version | \
            python3 -c 'from __future__ import print_function; import sys, json; \
            info = json.loads(sys.stdin.read()); \
            info and print("%s.%s" % (info["major"], info["minor"].rstrip("+")))') || true`
    fi
fi

if [ -z "$KUBECTL_VERSION" ]; then
    KUBECTL_VERSION=1.16
fi

if [ -z "$OC_VERSION" ]; then
    case "$KUBECTL_VERSION" in
        1.11|1.11+)
            OC_VERSION=3.11
            ;;
        1.13|1.13+)
            OC_VERSION=4.1
            ;;
        1.14|1.14+)
            OC_VERSION=4.2
            ;;
        *)
            OC_VERSION=4.2
            ;;
    esac
fi

export KUBECTL_VERSION
export OC_VERSION

# Setup the client configuration for the location of the Kubernetes
# cluster along with credentials. We do this in case we need to use a
# program that will not use the in-cluster config and requires
# ~/.kube/config instead. Also allows us to use a bearer token which
# is passed into the container.

CA_FILE="/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
NAMESPACE_FILE="/var/run/secrets/kubernetes.io/serviceaccount/namespace"
TOKEN_FILE="/var/run/secrets/kubernetes.io/serviceaccount/token"

if [ "$KUBERNETES_SERVER" != ":" ]; then
    if [ -f $CA_FILE ]; then
        KUBECTL_CA_ARGS="--certificate-authority $CA_FILE"
    else
        KUBECTL_CA_ARGS="--insecure-skip-tls-verify"
    fi

    CURRENT_CLUSTER=`echo $KUBERNETES_SERVER | tr '.' '-'`

    kubectl config set-cluster $CURRENT_CLUSTER $KUBECTL_CA_ARGS --server "https://$KUBERNETES_SERVER"

    if [ ! -z "$PROJECT_NAMESPACE" ]; then
        CURRENT_NAMESPACE=$PROJECT_NAMESPACE
    else
        if [ -f $NAMESPACE_FILE ]; then
            CURRENT_NAMESPACE=`cat $NAMESPACE_FILE` 
        else
            CURRENT_NAMESPACE=default
        fi
    fi

    CURRENT_USER=user/$CURRENT_CLUSTER

    if [ ! -z "$KUBERNETES_BEARER_TOKEN" ]; then
        kubectl config set-credentials $CURRENT_USER --token=$KUBERNETES_BEARER_TOKEN
    else
        if [ -f "$TOKEN_FILE" ]; then
            kubectl config set-credentials $CURRENT_USER --token=`cat $TOKEN_FILE`
        fi
    fi

    CURRENT_CONTEXT=$CURRENT_NAMESPACE/$CURRENT_CLUSTER/user

    kubectl config set-context $CURRENT_CONTEXT --cluster $CURRENT_CLUSTER --user $CURRENT_USER --namespace=$CURRENT_NAMESPACE

    kubectl config use-context $CURRENT_CONTEXT
fi

if [ -z "$PROJECT_NAMESPACE" ]; then
    PROJECT_NAMESPACE=$CURRENT_NAMESPACE
    if [ ! -z "$PROJECT_NAMESPACE" ]; then
        export PROJECT_NAMESPACE
    fi
fi

# Setup WebDAV configuration for when running Apache. Done here so that
# environment variables are available to the terminal to add an account.

WEBDAV_REALM=workshop
WEBDAV_USERFILE=/opt/app-root/etc/webdav.htdigest

export WEBDAV_REALM
export WEBDAV_USERFILE

if [ ! -s $WEBDAV_USERFILE ]; then
    touch $WEBDAV_USERFILE
fi
