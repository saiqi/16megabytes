FROM gitpod/workspace-full:latest
                    
USER root

RUN wget http://downloads.dlang.org/releases/2.x/2.098.1/dmd_2.098.1-0_amd64.deb
RUN sudo dpkg -i dmd_2.098.1-0_amd64.deb

USER gitpod
# apply user-specific settings

# give back control
USER root