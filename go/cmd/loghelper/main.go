package main

import (
	"bufio"
	"fmt"
	"io"
	"log"
	"os"
	"strings"
)

func main() {
	r := bufio.NewReader(os.Stdin)
	for {
		l, err := r.ReadString('\n')
		if err != nil {
			if err == io.EOF {
				return
			}
			log.Printf("LogHelper: error reading input: %v", err)
		}
		l = strings.Trim(l, " \t\n\r")
		if strings.HasPrefix(l, "L") {
			l = l[1:]
			_, _ = fmt.Fprintln(os.Stderr, l)
		}
	}
}
