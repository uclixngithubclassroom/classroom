FROM ruby:2.4.2

ENV PATH "$PATH:/root/.rbenv/bin"
ENV PATH "$PATH:/root/.rbenv/shims"
ENV BUNDLER_VERSION 2.0.2

RUN printf "deb http://archive.debian.org/debian/ jessie main\ndeb-src http://archive.debian.org/debian/ jessie main\ndeb http://security.debian.org jessie/updates main\ndeb-src http://security.debian.org jessie/updates main" > /etc/apt/sources.list

# install rubenv
RUN wget -q https://github.com/rbenv/rbenv-installer/raw/master/bin/rbenv-installer -O- | bash
RUN apt-get update -qq && apt-get install -y apt-transport-https

# install yarn and node
RUN wget -q https://deb.nodesource.com/setup_10.x -O- | bash -
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list

# install nodejs, postgres, redis, memcached
RUN apt-get update -qq && apt-get install -y yarn nodejs postgresql-client redis-server memcached 

RUN apt-get install -y --force-yes build-essential curl git

#App required to change file format to unix from windows
RUN apt install dos2unix

RUN apt-get install -y --force-yes zlib1g-dev libpq-dev netcat rinetd libssl-dev libreadline-dev libyaml-dev libxml2-dev libxslt-dev

RUN apt-get clean

#In case a user is using Windows OS, this command has to be executed to convert all files 
#to Unix format to prevent encoding errors.

RUN npm install npm@latest

# app init
WORKDIR /usr/src/app
ADD .ruby-version .
ADD script/bootstrap-sc .
#Json file contains the node modules to be installed
COPY package*.json ./
COPY vendor ./vendor
COPY . /usr/src/app
RUN dos2unix bootstrap-sc
RUN bash bootstrap-sc
RUN find . -type f -exec dos2unix -q {} \;
RUN ls -l

#Startup script and port forwarding
COPY config/rinetd.conf /etc/rinetd.conf