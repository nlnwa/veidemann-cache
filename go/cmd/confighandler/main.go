package main

import (
	"flag"
	"fmt"
	"github.com/nlnwa/veidemann-cache/go/internal/discovery"
	"github.com/nlnwa/veidemann-cache/go/internal/iputil"
	"github.com/sevlyar/go-daemon"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"strings"
	"time"
)

func main() {
	log.SetPrefix("[ConfigHandler] ")

	r := new(rewriter)

	flag.BoolVar(&r.balancer, "b", false, "Set to true to configure squid as balancer")
	flag.Parse()

	// configure rewriter
	r.configPath = "/etc/squid/squid.conf"
	if r.balancer {
		log.Print("Configuring squid as balancer")
		r.templatePath = "/etc/squid/squid-balancer.conf.template"
		r.discovery = discovery.NewDiscovery()
	} else {
		log.Print("Configuring squid as cache")
		r.templatePath = "/etc/squid/squid.conf.template"
	}

	// initial config rewrite
	if err := r.rewriteConfig(); err != nil {
		log.Fatalf("Failed to initialize configuration: %v", err)
	}

	// fork daemon process
	context := &daemon.Context{LogFileName: "/proc/self/fd/2"}
	child, err := context.Reborn()
	if err != nil {
		log.Fatalf("Failed to create daemon process: %v", err)
	}
	if child != nil {
		// This code is run in parent process
		log.Printf("Configuration initialized: %s", r.configPath)
	} else {
		// This code is run in forked child
		log.Println("Daemon started")
		defer func() {
			_ = context.Release()
			log.Println("Daemon stopped")
		}()
		for {
			time.Sleep(5 * time.Second)
			if err := r.rewriteConfig(); err != nil {
				log.Printf("Failed to rewrite configuration: %v", err)
			}
			if r.changes {
				if err := reconfigureSquid(); err != nil {
					log.Printf("Error reloading squid configuration: %v", err)
				}
			}
		}
	}
}

type rewriter struct {
	lastParents    string
	lastDnsServers string
	discovery      *discovery.Discovery
	balancer       bool
	templatePath   string
	configPath     string
	changes        bool
}

func (r *rewriter) rewriteConfig() error {
	r.changes = false
	parents := ""
	if r.balancer {
		var err error
		parents, err = r.getParents()
		if err != nil {
			return fmt.Errorf("failed to get parents: %w", err)
		}
		if parents == "" {
			return fmt.Errorf("found no parents")
		}
	}
	dnsServers := r.getDnsServersString()
	if dnsServers == "" {
		return fmt.Errorf("no dns servers configured")
	}

	if parents != r.lastParents || dnsServers != r.lastDnsServers {
		// read template
		b, err := ioutil.ReadFile(r.templatePath)
		if err != nil {
			return fmt.Errorf("failed to read template (%s): %w", r.templatePath, err)
		}
		// substitute template variables
		conf := string(b)
		conf = strings.Replace(conf, "${DNS_IP}", dnsServers, 1)
		if r.balancer {
			conf = strings.Replace(conf, "${PARENTS}", parents, 1)
		}
		// write config
		if err := ioutil.WriteFile(r.configPath, []byte(conf), 777); err != nil {
			return fmt.Errorf("failed to write config (%s): %w", r.configPath, err)
		}
		r.changes = true
	}

	r.lastParents = parents
	r.lastDnsServers = dnsServers
	return nil
}

func (r *rewriter) getParents() (string, error) {
	parents, err := r.discovery.GetParents()
	if err != nil {
		return "", err
	}
	var peers string
	for _, parent := range parents {
		peers += fmt.Sprintf("cache_peer %v parent 3128 0 carp no-digest\n", parent)
	}
	return peers, nil
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

func reconfigureSquid() error {
	log.Printf("Reconfiguring squid...")
	cmd := exec.Command("squid", "-k", "reconfigure")
	// ignore error returned if wait was already called
	defer func() { _ = cmd.Wait() }()

	stderr, err := cmd.StderrPipe()
	if err != nil {
		return fmt.Errorf("failed to pipe stderr [%s]: %w", cmd.String(), err)
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return fmt.Errorf("failed to pipe stdout [%s]: %w", cmd.String(), err)
	}

	if err := cmd.Start(); err != nil {
		return fmt.Errorf("failed to start [%s]", cmd.String())
	}

	if slurp, err := ioutil.ReadAll(stdout); err != nil {
		return fmt.Errorf("failed to read standard out [%s]", cmd.String())
	} else {
		log.Print(slurp)
	}
	if slurp, err := ioutil.ReadAll(stderr); err != nil {
		return fmt.Errorf("failed to read standard err [%s]", cmd.String())
	} else {
		log.Print(slurp)
	}

	if err := cmd.Wait(); err != nil {
		return err
	}
	return nil
}
