package main

import (
	"bufio"
	"fmt"
	"io"
	"log"
	"os"
	"strings"
)

const thread_count = 5

func main() {
	i := make(chan string)
	o := make(chan string)

	log.Printf("Starting storeid with %v threads", thread_count)
	go writeOutput(o)
	for j := 0; j < thread_count; j++ {
		go rewriter(i, o)
	}
	scanInput(i)
}

func scanInput(i chan string) {
	r := bufio.NewReader(os.Stdin)
	for {
		l, err := r.ReadString('\n')
		if err != nil {
			if err == io.EOF {
				return
			}
			log.Print("Error reading input")
		}
		i <- l
	}
}

func writeOutput(o chan string) {
	for s := range o {
		fmt.Print(s)
	}
}

func rewriter(i chan string, o chan string) {
	for s := range i {
		o <- rewrite(s)
	}
}

func rewrite(s string) string {
	l := strings.Trim(s, " \t\r\n")

	var (
		res       string
		channelId string
		url       string
		extras    string
	)

	parts := strings.SplitN(l, " ", 3)
	channelId = parts[0]
	url = parts[1]
	if len(parts) > 2 {
		extras = parts[2]
	}

	p := strings.SplitN(url, ":", 2)
	if extras == "-" || p[0] == "cache_object" {
		res = url
	} else {
		res = extras + url
	}

	log.Printf("CHANNEL: %s, STORE ID: %s", channelId, res)
	return fmt.Sprintf("%s OK store-id=\"%s\"\n", channelId, res)
}
