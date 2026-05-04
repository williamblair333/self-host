import argparse
import subprocess
import sys

def transfer_file(key_path, source_path, target):
    if key_path:
        scp_command = f'scp -i {key_path} {source_path} {target}'
    else:
        scp_command = f'scp {source_path} {target}'
    
    process = subprocess.Popen(scp_command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = process.communicate()

    # Print verbose output for debugging
    print(f'STDOUT: {stdout.decode()}')
    print(f'STDERR: {stderr.decode()}')

    if process.returncode != 0:
        print(f"Failed to transfer file: {stderr.decode()}")
        sys.exit(1)
    else:
        print(f"File transferred successfully to {target}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Transfer files via SCP.')
    parser.add_argument('--key', help='Path to the authentication key', default=None)
    parser.add_argument('--source', required=True, help='Path to the source file')
    parser.add_argument('--target', required=True, help='Destination in the format user@host:/path')
    args = parser.parse_args()

    transfer_file(args.key, args.source, args.target)
