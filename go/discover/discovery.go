package discover

import (
	"io/ioutil"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/labels"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
	"log"
	"net"
	"os"
)

type Discovery struct {
	ns          string
	serviceName string
	myIp        string
	kube        *kubernetes.Clientset
}

func NewDiscovery() *Discovery {
	// creates the in-cluster config
	config, err := rest.InClusterConfig()
	if err != nil {
		panic(err.Error())
	}
	// creates the clientset
	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		panic(err.Error())
	}

	serviceName, _ := os.LookupEnv("SERVICE_NAME")

	d := &Discovery{
		ns:          getNamespace(),
		serviceName: serviceName,
		myIp:        GetOutboundIP().String(),
		kube:        clientset,
	}
	return d
}

func getNamespace() string {
	b, err := ioutil.ReadFile("/var/run/secrets/kubernetes.io/serviceaccount/namespace")
	if err != nil {
		panic(err.Error())
	}
	return string(b)
}

// Get preferred outbound ip of this machine
func GetOutboundIP() net.IP {
	conn, err := net.Dial("udp", "8.8.8.8:80")
	if err != nil {
		log.Fatal(err)
	}
	defer conn.Close()

	localAddr := conn.LocalAddr().(*net.UDPAddr)

	return localAddr.IP
}

func (d *Discovery) GetSiblings() []string {
	var siblings []string
	service, err := d.kube.CoreV1().Services(d.ns).Get(d.serviceName, metav1.GetOptions{})
	if err != nil {
		log.Print(err.Error())
		return siblings
	}
	set := labels.Set(service.Spec.Selector)
	eps, err := d.kube.CoreV1().Endpoints(d.ns).List(metav1.ListOptions{LabelSelector: set.AsSelector().String()})
	if err != nil {
		log.Print(err.Error())
		return siblings
	}

	for _, ep := range eps.Items {
		for _, ss := range ep.Subsets {
			for _, a := range ss.Addresses {
				//if a.IP != d.myIp {
					siblings = append(siblings, a.IP)
				//}
			}
		}
	}
	return siblings
}
