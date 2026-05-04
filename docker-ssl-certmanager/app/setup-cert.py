import subprocess
import sys

def generate_certificate(domain):
    command = [
        "openssl", "req", 
        "-new", 
        "-newkey", "rsa:2048", 
        "-days", "365", 
        "-nodes", 
        "-x509", 
        "-subj", f"/C=US/ST=State/L=City/O=Organization/CN={domain}", 
        "-keyout", f"/app/certs/{domain}.key", 
        "-out", f"/app/certs/{domain}.crt"
    ]
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = process.communicate()

    if process.returncode != 0:
        print(f"Failed to generate certificate for {domain}: {stderr.decode()}")
        sys.exit(1)
    else:
        print(f"Certificate generated successfully for {domain}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python setup-cert.py <domain>")
        sys.exit(1)
    domain = sys.argv[1]
    generate_certificate(domain)
