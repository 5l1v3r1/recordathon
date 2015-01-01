package main

import (
	"encoding/base64"
	"encoding/json"
	"github.com/hoisie/mustache"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"sync"
)

var AssetsPath string
var RootPath string
var CutsPath string
var Cuts map[string]CutData = map[string]CutData{}
var GlobalLock sync.Mutex

type CutData struct {
	Start float64 `json:"start"`
	End   float64 `json:"end"`
}

type UploadData struct {
	Name string  `json:"name"`
	Data string  `json:"data"`
	Cut  CutData `json:"cut"`
}

func main() {
	if len(os.Args) != 3 {
		log.Fatal("Usage: ", os.Args[0], " <port> <root path>")
	}

	// Setup configuration
	var err error
	_, filePath, _, _ := runtime.Caller(0)
	AssetsPath = filepath.Join(filepath.Dir(filePath), "assets")
	RootPath, err = filepath.Abs(os.Args[2])
	if err != nil {
		log.Fatal("Failed to get absolute root path: ", err)
	}
	CutsPath = filepath.Join(RootPath, "cuts.json")
	if content, err := ioutil.ReadFile(CutsPath); err == nil {
		json.Unmarshal(content, &Cuts)
	}

	// Setup server
	if _, err := strconv.Atoi(os.Args[1]); err != nil {
		log.Fatal("Invalid port number: ", os.Args[1])
	}
	http.HandleFunc("/upload", HandleUpload)
	http.HandleFunc("/", HandleHome)
	if err := http.ListenAndServe(":"+os.Args[1], nil); err != nil {
		log.Fatal("Error listening: ", err)
	}
}

func HandleHome(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		HandleOther(w, r)
		return
	}

	listing, err := ReadListing()
	if err != nil {
		log.Fatal("Failed to read listing: ", err)
	}

	info := map[string][]string{"files": listing}
	templatePath := filepath.Join(AssetsPath, "index.mustache")
	body := mustache.RenderFile(templatePath, info)
	w.Header().Set("Content-Type", "text/html")
	w.Write([]byte(body))
}

func HandleOther(w http.ResponseWriter, r *http.Request) {
	// I'm not really sure why I care about security in such a small project,
	// but I might as well sanitize the path a bit.
	cleaned := strings.Replace(r.URL.Path, "..", "", -1)
	log.Print("Serving static: ", cleaned)
	http.ServeFile(w, r, filepath.Join(AssetsPath, cleaned))
}

func HandleUpload(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	// Yes, I am really just reading the whole request into RAM.
	raw, err := ioutil.ReadAll(r.Body)
	if err != nil {
		log.Print("Failed to read upload body.")
		w.Write([]byte("false"))
		return
	}

	// Parse the JSON the lazy way.
	var data UploadData
	if json.Unmarshal(raw, &data) != nil {
		log.Print("Got invalid upload JSON.")
		w.Write([]byte("false"))
		return
	}

	// Decode the base64 data
	contents, err := base64.StdEncoding.DecodeString(data.Data)
	if err != nil {
		log.Print("Got invalid base64 upload.")
		w.Write([]byte("false"))
		return
	}

	// Once again, security is not *really* a concern, but I'll sanitize the
	// name anyway.
	name := strings.Replace(data.Name, "/", "", -1)
	name = strings.Replace(name, ".", "", -1)

	GlobalLock.Lock()
	defer GlobalLock.Unlock()

	// Save audio file
	localPath := filepath.Join(RootPath, name+".wav")
	err = ioutil.WriteFile(localPath, contents, os.FileMode(0777))
	if err != nil {
		log.Fatal("Failed to save uploaded file: ", err)
	}

	// Save cuts data
	Cuts[name] = data.Cut
	cutsData, err := json.Marshal(Cuts)
	if err != nil {
		log.Fatal("Failed to marshal cut data: ", err)
	}
	err = ioutil.WriteFile(CutsPath, cutsData, os.FileMode(0777))
	if err != nil {
		log.Fatal("Failed to save cuts.json: ", err)
	}

	w.Write([]byte("true"))
}

func ReadListing() ([]string, error) {
	GlobalLock.Lock()
	defer GlobalLock.Unlock()

	// Read the directory
	f, err := os.Open(RootPath)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	names, err := f.Readdirnames(-1)
	if err != nil {
		return nil, err
	}
	res := make([]string, 0, len(names))
	for _, name := range names {
		if strings.HasSuffix(name, ".wav") {
			res = append(res, name)
		}
	}

	return res, nil
}
