package main

import (
	"flag"
	"fmt"
	"github.com/sevlyar/go-daemon"
	"io/ioutil"
	"log"
	"nlnwa/veidemann-cache/go/discover"
	"nlnwa/veidemann-cache/go/iputil"
	"os"
	"os/exec"
	"strings"
	"time"
)

func main() {
	r := &rewriter{}

	flag.BoolVar(&r.balancer, "b", false, "Set to true to make this node a non-caching load balancing node")
	flag.Parse()

	if r.balancer {
		log.Print("Confighandler: Init squid as balancer")
		r.discovery = discover.NewDiscovery()
	} else {
		log.Print("Confighandler: Init squid cache")
	}
	r.check()

	context := &daemon.Context{LogFileName: "/proc/self/fd/2"}
	child, err := context.Reborn()
	if err != nil {
		log.Fatal("Confighandler: Unable to run: ", err)
	}

	if child != nil {
		// This code is run in parent process
		log.Printf("Confighandler: Init done")
		return
	} else {
		// This code is run in forked child
		defer context.Release()
		log.Print("Confighandler: daemon started")
		for {
			r.check()
			time.Sleep(5 * time.Second)
		}
	}
}

type rewriter struct {
	lastParents    string
	lastDnsServers string
	discovery      *discover.Discovery
	balancer       bool
}

func (r *rewriter) check() {
	parents := ""
	if r.balancer {
		parents = r.getParentsString()
	}
	dnsServers := r.getDnsServersString()

	if parents != r.lastParents || dnsServers != r.lastDnsServers {
		conf := r.rewriteConfig(dnsServers, parents)
		r.writeConfig(conf)
	}

	r.lastParents = parents
	r.lastDnsServers = dnsServers
}

func (r *rewriter) getParentsString() string {
	s := r.discovery.GetSiblings()
	var siblings string
	for _, a := range s {
		siblings += fmt.Sprintf("cache_peer %v parent 3128 0 carp no-digest\n", a)
	}
	return siblings
}

func (r *rewriter) getDnsServersString() string {
	var dnsServers string

	dnsEnv, _ := os.LookupEnv("DNS_SERVERS")
	dns := strings.Split(dnsEnv, " ")

	for _, d := range dns {
		ip, _, err := iputil.IPAndPortForAddr(strings.TrimSpace(d), 53)
		if err == nil {
			dnsServers += ip + " "
		}
	}
	return dnsServers
}

func (r *rewriter) rewriteConfig(dnsServers string, parents string) string {
	var templatePath string
	if r.balancer {
		templatePath = "/etc/squid/squid-balancer.conf.template"
	} else {
		templatePath = "/etc/squid/squid.conf.template"
	}
	b, err := ioutil.ReadFile(templatePath)
	if err != nil {
		panic(err.Error())
	}

	conf := string(b)
	conf = strings.Replace(conf, "${DNS_IP}", dnsServers, 1)
	conf = strings.Replace(conf, "${PARENTS}", parents, 1)

	return conf
}

func (r *rewriter) writeConfig(conf string) {
	err := ioutil.WriteFile("/etc/squid/squid.conf", []byte(conf), 777)
	if err != nil {
		log.Print(err)
	}

	p, err := ioutil.ReadFile("/var/run/squid/squid.pid")
	if err != nil {
		log.Printf("Confighandler: No squid is running %v", err.Error())
		return
	}

	log.Printf("Confighandler: Reloading squid config...")
	cmd := exec.Command("kill", "-HUP", strings.Trim(string(p), " \n\r\t"))

	stderr, err := cmd.StderrPipe()
	if err != nil {
		log.Fatal(err)
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		log.Fatal(err)
	}

	if err := cmd.Start(); err != nil {
		log.Fatal(err)
	}

	slurp, _ := ioutil.ReadAll(stdout)
	log.Printf("%s\n", slurp)
	slurp, _ = ioutil.ReadAll(stderr)
	log.Printf("%s\n", slurp)

	if err := cmd.Wait(); err != nil {
		log.Printf("Confighandler: Reloading squid config finished with error: %v", err)
	}
}
