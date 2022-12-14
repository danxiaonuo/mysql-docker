#############################
#     设置公共的变量         #
#############################
ARG BASE_IMAGE_TAG=22.04
FROM ubuntu:${BASE_IMAGE_TAG}

# 作者描述信息
MAINTAINER danxiaonuo
# 时区设置
ARG TZ=Asia/Shanghai
ENV TZ=$TZ
# 语言设置
ARG LANG=zh_CN.UTF-8
ENV LANG=$LANG

# 镜像变量
ARG DOCKER_IMAGE=danxiaonuo/mysql
ENV DOCKER_IMAGE=$DOCKER_IMAGE
ARG DOCKER_IMAGE_OS=ubuntu
ENV DOCKER_IMAGE_OS=$DOCKER_IMAGE_OS
ARG DOCKER_IMAGE_TAG=22.04
ENV DOCKER_IMAGE_TAG=$DOCKER_IMAGE_TAG

# mysql版本号
ARG MYSQL_MAJOR=8.0
ENV MYSQL_MAJOR=$MYSQL_MAJOR
ARG MYSQL_VERSION=${MYSQL_MAJOR}.30-22
ENV MYSQL_VERSION=$MYSQL_VERSION

# 工作目录
ARG MYSQL_DIR=/var/lib/mysql
ENV MYSQL_DIR=$MYSQL_DIR
# 数据目录
ARG MYSQL_DATA=/var/lib/mysql
ENV MYSQL_DATA=$MYSQL_DATA

# 环境设置
ARG DEBIAN_FRONTEND=noninteractive
ENV DEBIAN_FRONTEND=$DEBIAN_FRONTEND

# 源文件下载路径
ARG DOWNLOAD_SRC=/tmp
ENV DOWNLOAD_SRC=$DOWNLOAD_SRC

# 安装依赖包
ARG PKG_DEPS="\
    zsh \
    bash \
    bash-completion \
    dnsutils \
    iproute2 \
    net-tools \
    ncat \
    git \
    vim \
    tzdata \
    curl \
    wget \
    axel \
    lsof \
    zip \
    unzip \
    rsync \
    iputils-ping \
    telnet \
    procps \
    libaio1 \
    numactl \
    xz-utils \
    gnupg2 \
    psmisc \
    libmecab2 \
    debsums \
    locales \
    language-pack-zh-hans \
    ca-certificates"
ENV PKG_DEPS=$PKG_DEPS

# ***** 安装依赖 *****
RUN set -eux && \
   # 更新源地址
   sed -i s@http://*.*ubuntu.com@https://mirrors.aliyun.com@g /etc/apt/sources.list && \
   # 解决证书认证失败问题
   touch /etc/apt/apt.conf.d/99verify-peer.conf && echo >>/etc/apt/apt.conf.d/99verify-peer.conf "Acquire { https::Verify-Peer false }" && \
   # 更新系统软件
   DEBIAN_FRONTEND=noninteractive apt-get update -qqy && apt-get upgrade -qqy && \
   # 安装依赖包
   DEBIAN_FRONTEND=noninteractive apt-get install -qqy --no-install-recommends $PKG_DEPS && \
   DEBIAN_FRONTEND=noninteractive apt-get -qqy --no-install-recommends autoremove --purge && \
   DEBIAN_FRONTEND=noninteractive apt-get -qqy --no-install-recommends autoclean && \
   rm -rf /var/lib/apt/lists/* && \
   # 更新时区
   ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime && \
   # 更新时间
   echo ${TZ} > /etc/timezone && \
   # 更改为zsh
   sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || true && \
   sed -i -e "s/bin\/ash/bin\/zsh/" /etc/passwd && \
   sed -i -e 's/mouse=/mouse-=/g' /usr/share/vim/vim*/defaults.vim && \
   locale-gen zh_CN.UTF-8 && localedef -f UTF-8 -i zh_CN zh_CN.UTF-8 && locale-gen && \
   /bin/zsh

# add gosu for easy step-down from root
# https://github.com/tianon/gosu/releases
ENV GOSU_VERSION 1.14
RUN set -eux; \
	savedAptMark="$(apt-mark showmanual)"; \
	dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
	wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
	wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
	gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc; \
	apt-mark auto '.*' > /dev/null; \
	[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark > /dev/null; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	chmod +x /usr/local/bin/gosu; \
	gosu --version; \
	gosu nobody true
    
# ***** 拷贝文件 *****
COPY ["ps-entry.sh", "/docker-entrypoint.sh"]

# ***** 下载mysql *****
RUN set -eux && \
    # 设置mysql用户
    groupadd -r mysql && useradd -r -g mysql mysql && \
    # 下载mysql
    wget --no-check-certificate https://downloads.percona.com/downloads/Percona-Server-LATEST/Percona-Server-${MYSQL_VERSION}/binary/debian/jammy/x86_64/percona-server-common_${MYSQL_VERSION}-1.jammy_amd64.deb \
    -O ${DOWNLOAD_SRC}/percona-server-common_${MYSQL_VERSION}-1.jammy_amd64.deb && \
    wget --no-check-certificate https://downloads.percona.com/downloads/Percona-Server-LATEST/Percona-Server-${MYSQL_VERSION}/binary/debian/jammy/x86_64/percona-server-server_${MYSQL_VERSION}-1.jammy_amd64.deb \
    -O ${DOWNLOAD_SRC}/percona-server-server_${MYSQL_VERSION}-1.jammy_amd64.deb && \
    wget --no-check-certificate https://downloads.percona.com/downloads/Percona-Server-LATEST/Percona-Server-${MYSQL_VERSION}/binary/debian/jammy/x86_64/percona-server-client_${MYSQL_VERSION}-1.jammy_amd64.deb \
    -O ${DOWNLOAD_SRC}/percona-server-client_${MYSQL_VERSION}-1.jammy_amd64.deb && \
    # 安装percona-mysql
    dpkg -i ${DOWNLOAD_SRC}/*.deb && \
    # 删除临时文件
    rm -rf /var/lib/apt/lists/* ${DOWNLOAD_SRC}/*.deb && \
    rm -rf ${MYSQL_DIR} /etc/my.cnf /etc/mysql /etc/my.cnf.d && \
    # 创建相关目录
    mkdir -p ${MYSQL_DIR} /var/run/mysqld /docker-entrypoint-initdb.d && \
    chown -R mysql:mysql ${MYSQL_DIR} /var/run/mysqld && \
    chmod 1777 ${MYSQL_DIR} /var/run/mysqld /docker-entrypoint.sh && \
    cp -arf /root/.oh-my-zsh ${MYSQL_DIR}/.oh-my-zsh && \
    cp -arf /root/.zshrc ${MYSQL_DIR}/.zshrc && \
    sed -i '5s#/root/.oh-my-zsh#${MYSQL_DIR}/.oh-my-zsh#' ${MYSQL_DIR}/.zshrc

# ***** 拷贝文件 *****
COPY ["conf/mysql/", "/etc/mysql/"]

# ***** 容器信号处理 *****
STOPSIGNAL SIGQUIT

# ***** 监听端口 *****
EXPOSE 3306 33060 33061

# ***** 工作目录 *****
WORKDIR ${MYSQL_DIR}

# ***** 挂载目录 *****
VOLUME ${MYSQL_DATA}

# ***** 入口 *****
ENTRYPOINT ["/docker-entrypoint.sh"]

# ***** 执行命令 *****
CMD ["mysqld"]
