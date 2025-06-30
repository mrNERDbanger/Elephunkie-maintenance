#!/bin/bash

# Script to generate self-signed SSL certificates for Elephunkie local server

echo "Generating SSL certificates for Elephunkie..."

# Create certificates directory
mkdir -p ../Resources/Certificates

# Generate private key
openssl genrsa -out ../Resources/Certificates/server.key 2048

# Generate certificate signing request
openssl req -new -key ../Resources/Certificates/server.key \
    -out ../Resources/Certificates/server.csr \
    -subj "/C=US/ST=CA/L=San Francisco/O=Elephunkie/CN=localhost"

# Generate self-signed certificate
openssl x509 -req -days 365 \
    -in ../Resources/Certificates/server.csr \
    -signkey ../Resources/Certificates/server.key \
    -out ../Resources/Certificates/server.crt

# Create PEM file (combined certificate and key)
cat ../Resources/Certificates/server.crt ../Resources/Certificates/server.key > ../Resources/Certificates/server.pem

# Set appropriate permissions
chmod 600 ../Resources/Certificates/server.key
chmod 644 ../Resources/Certificates/server.crt
chmod 644 ../Resources/Certificates/server.pem

echo "SSL certificates generated successfully!"
echo "Certificate: ../Resources/Certificates/server.crt"
echo "Private Key: ../Resources/Certificates/server.key"
echo "Combined PEM: ../Resources/Certificates/server.pem"

# Clean up CSR file
rm ../Resources/Certificates/server.csr