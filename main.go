package main

import (
	"io"
	"net"
	"os"
)

func main() {
    ln, _ := net.Listen("tcp", "localhost:8080")
    defer ln.Close()

    for {
        conn, _ := ln.Accept()
        go func(conn net.Conn) {
            defer conn.Close();
            file, _ := os.Open("file.flv")
            defer file.Close()
            _, _ = io.Copy(conn, file)
        }(conn)
    }
}
