FROM jenkins/jenkins:lts-jdk11
USER root

# Your needed installations goes here
# Reason for this line: https://github.com/debuerreotype/docker-debian-artifacts/issues/24
RUN mkdir -p /usr/share/man/man1

RUN apt-get -y update && apt-get -y upgrade && \
    apt-get install -y python3 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY scripts/* /usr/local/bin/
RUN chmod 755 /usr/local/bin/dbt
RUN chmod 755 /usr/local/bin/pre-commit
RUN chmod 755 /usr/local/bin/sendmail

#RUN pip install --upgrade pip setuptools wheel
#
#COPY requirements.txt /tmp/requirements.txt
#RUN pip install -r /tmp/requirements.txt

USER jenkins
