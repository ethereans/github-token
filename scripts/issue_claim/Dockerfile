FROM ubuntu:14.04
RUN apt-get update && apt-get install -y python
ADD issue_status.py issue_status.py
MAINTAINER Ricardo “3esmit@gmail.com”
CMD python issue_status.py