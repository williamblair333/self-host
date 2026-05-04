import sys
from ssh_util import create_ssh_client, execute_command, close_ssh_client

def restart_web_server(server_ip, web_server):
    ssh = create_ssh_client(server_ip)
    command = f'sudo systemctl restart {web_server}'
    execute_command(ssh, command)
    close_ssh_client(ssh)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python web_server_util.py <server_ip> <web_server>")
        sys.exit(1)

    server_ip, web_server = sys.argv[1:3]
    restart_web_server(server_ip, web_server)
