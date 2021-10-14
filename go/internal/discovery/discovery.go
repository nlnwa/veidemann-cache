package discovery

import (
	"context"
	"fmt"
	metaV1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/labels"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
	"os"
	"time"
)

type Discovery struct {
	ns          string
	serviceName string
	kube        *kubernetes.Clientset
}

func NewDiscovery() *Discovery {
	// creates the in-cluster config
	config, err := rest.InClusterConfig()
	if err != nil {
		panic(err)
	}
	// creates the clientset
	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		panic(err)
	}

	serviceName, ok := os.LookupEnv("SERVICE_NAME")
	if !ok {
		panic("failed to lookup env SERVICE_NAME")
	}
	namespace, ok := os.LookupEnv("NAMESPACE")
	if !ok {
		panic("failed to lookup environment variable NAMESPACE")
	}

	return &Discovery{
		ns:          namespace,
		serviceName: serviceName,
		kube:        clientset,
	}
}

func (d *Discovery) GetPeers() ([]string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	var peers []string
	service, err := d.kube.CoreV1().Services(d.ns).Get(ctx, d.serviceName, metaV1.GetOptions{})
	if err != nil {
		return nil, fmt.Errorf("failed to get service named %s: %w", d.serviceName, err)
	}
	eps, err := d.kube.DiscoveryV1().EndpointSlices(d.ns).List(ctx, metaV1.ListOptions{
		LabelSelector: labels.Set(service.Spec.Selector).AsSelector().String(),
	})
	if err != nil {
		return nil, fmt.Errorf("failed to get endpoints for service named %s: %w", d.serviceName, err)
	}

	for _, ep := range eps.Items {
		for _, ss := range ep.Endpoints {
			for _, a := range ss.Addresses {
				peers = append(peers, a)
			}
		}
	}
	return peers, nil
}