# pyinfra Server in a Docker Debian Container

--guide here https://docs.pyinfra.com/en/2.x/getting-started.html

# Setup 
Read over the docker_pyinfra_install.sh file and make changes accordingly.  Using pip3 instead of Debian packages.  Running that file will create the Dockerfile, its image and a docker-compose.yaml file.  Don't forget to chmod +x the executable .sh files. The provided Dockerfile and docker-compose.yaml are examples.

# Regarding curls and wgets 
For wget (and maybe curl) to work, ca-certificates package needs to be installed.  You may also need to destroy any external network you're using (along with containers that use it) and recreate the network setting the mtu to 1400~ish.  Here's an example  
    ```docker network create \```  
    ```--driver=bridge \```  
    ```--subnet=172.16.0.0/26 \```  
    ```--ip-range=172.16.0.0/27 \```  
    ```--gateway=172.16.0.1 \```  
    ```-o com.docker.network.driver.mtu=1400 \```  
    ```<network_name>```  
  
# Image
Get the latest image at https://hub.docker.com/r/williamblair333/pyinfra

# Note on Alias Usage

Precede any scripts with a . before running any scripts that might rely on aliases.  The best thing to do for production / permanent files would be functions though.  Here is an example of using the "dot command" to make your environment accessible to scripts.  
```. ./your_script.sh```  

# Example Usage

Your script pyinfra calls can look something like this (creating a role):  
```docker exec -it pyinfra_pyinfra_1 pyinfra```  
  
Create an alias in ~/.bashrc or ad-hoc to run commands as if ansible were installed:  
  
```BASHRC=~/.bashrc
cat << EOF >> "$BASHRC"

#pyinfra alias commands begin
alias pyinfra='docker exec -it pyinfra_pyinfra_1 pyinfra'
#pyinfra alias commands end
EOF
