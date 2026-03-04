package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"html/template"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"
)

type Lease struct {
	Expiry          int64  `json:"expiry"`
	ExpiryFormatted string `json:"expiry_formatted"`
	MAC             string `json:"mac"`
	IP              string `json:"ip"`
	Hostname        string `json:"hostname"`
	ClientID        string `json:"client_id"`
}

func parseLeases(path string) ([]Lease, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	var leases []Lease
	for _, line := range strings.Split(strings.TrimSpace(string(data)), "\n") {
		if line == "" {
			continue
		}
		fields := strings.Fields(line)
		if len(fields) < 5 {
			fmt.Fprintf(os.Stderr, "Failed to parse dnsmasq lease line, to few fields: %q", line)
			continue
		}

		expiry, err := strconv.ParseInt(fields[0], 10, 64)
		if err != nil {
			continue
		}

		hostname := fields[3]
		if hostname == "*" {
			hostname = ""
		}

		leases = append(leases, Lease{
			Expiry:          expiry,
			ExpiryFormatted: time.Unix(expiry, 0).Format(time.RFC3339),
			MAC:             fields[1],
			IP:              fields[2],
			Hostname:        hostname,
			ClientID:        fields[4],
		})
	}
	return leases, nil
}

var htmlTemplate = template.Must(template.New("leases").Parse(`<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>DHCP Leases</title>
<style>
	body { font-family: sans-serif; margin: 2em; }
	table { border-collapse: collapse; width: 100%; }
	th, td { border: 1px solid #ccc; padding: 0.5em 1em; text-align: left; }
	th { background: #f0f0f0; }
	tr:hover { background: #f9f9f9; }
</style>
</head>
<body>
<h1>DHCP Leases</h1>
<table>
<tr><th>IP</th><th>MAC</th><th>Hostname</th><th>Expires</th></tr>
{{range . -}}
<tr><td>{{.IP}}</td><td>{{.MAC}}</td><td>{{.Hostname}}</td><td>{{.ExpiryFormatted}}</td></tr>
{{end}}
</table>
</body>
</html>
`))

func main() {
	listen := flag.String("listen", ":8080", "listen address")
	leasesPath := flag.String("leases", "/var/lib/misc/dnsmasq.leases", "path to dnsmasq leases file")
	flag.Parse()

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		leases, err := parseLeases(*leasesPath)
		if err != nil {
			http.Error(w, fmt.Sprintf("failed to read leases: %v", err), http.StatusInternalServerError)
			return
		}

		accept := r.Header.Get("Accept")
		if strings.Contains(accept, "application/json") {
			w.Header().Set("Content-Type", "application/json")
			encoder := json.NewEncoder(w)
			encoder.SetIndent("", "  ")
			encoder.Encode(leases)
			return
		}

		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		htmlTemplate.Execute(w, leases)
	})

	log.Printf("listening on %s", *listen)
	log.Fatal(http.ListenAndServe(*listen, nil))
}
