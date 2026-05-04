from paramiko import SSHClient, AutoAddPolicy, RSAKey
import argparse
import os

def create_ssh_client(server_ip, key_path=None, host_key_path=None):
    ssh = SSHClient()
    if host_key_path and os.path.isfile(host_key_path):
        # Load the host key
        host_key = RSAKey(filename=host_key_path)
        # Add the host key
        ssh.get_host_keys().add(server_ip, 'ssh-rsa', host_key)
    else:
        ssh.set_missing_host_key_policy(AutoAddPolicy())
    ssh.connect(server_ip, key_filename=key_path)
    return ssh

def execute_command(ssh, command):
    stdin, stdout, stderr = ssh.exec_command(command)
    error = stderr.read().decode()
    if error:
        print(f"Failed to execute command: {error}")
    else:
        print(stdout.read().decode())

def close_ssh_client(ssh):
    ssh.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Execute commands on a remote server via SSH.')
    parser.add_argument('--server', required=True, help='IP address of the remote server')
    parser.add_argument('--command', required=True, help='Command to execute on the remote server')
    parser.add_argument('--key', help='Path to the authentication key', default=None)
    parser.add_argument('--hostkey', help='Path to the remote host public key', default=None)
    args = parser.parse_args()

    ssh = create_ssh_client(args.server, args.key, args.hostkey)
    execute_command(ssh, args.command)
    close_ssh_client(ssh)
