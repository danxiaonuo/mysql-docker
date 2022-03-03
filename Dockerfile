#############################
#     设置公共的变量         #
#############################
ARG BASE_IMAGE_TAG=20.04
FROM ubuntu:${BASE_IMAGE_TAG}

# 作者描述信息
MAINTAINER danxiaonuo
# 时区设置
ARG TZ=Asia/Shanghai
ENV TZ=$TZ
# 语言设置
ARG LANG=C.UTF-8
ENV LANG=$LANG

# 镜像变量
ARG DOCKER_IMAGE=danxiaonuo/mysql
ENV DOCKER_IMAGE=$DOCKER_IMAGE
ARG DOCKER_IMAGE_OS=ubuntu
ENV DOCKER_IMAGE_OS=$DOCKER_IMAGE_OS
ARG DOCKER_IMAGE_TAG=20.04
ENV DOCKER_IMAGE_TAG=$DOCKER_IMAGE_TAG

# mysql版本号
ARG MYSQL_MAJOR=8.0
ENV MYSQL_MAJOR=$MYSQL_MAJOR
ARG MYSQL_VERSION=${MYSQL_MAJOR}.27-18
ENV MYSQL_VERSION=$MYSQL_VERSION

# 工作目录
ARG MYSQL_DIR=/data/mysql
ENV MYSQL_DIR=$MYSQL_DIR
# 环境变量
ARG PATH=/data/mysql/bin:$PATH
ENV PATH=$PATH
# ARG LD_PRELOAD=/usr/lib64/libjemalloc.so.1
# ENV LD_PRELOAD=$LD_PRELOAD
# 源文件下载路径
ARG DOWNLOAD_SRC=/tmp/src
ENV DOWNLOAD_SRC=$DOWNLOAD_SRC

# 安装依赖包
ARG PKG_DEPS="\
    zsh \
    bash \
    dnsutils \
    iproute2 \
    net-tools \
    git \
    vim \
    tzdata \
    curl \
    wget \
    lsof \
    zip \
    unzip \
    sudo \
    tree \
    htop \
    screen \
    lrzsz \
    xz-utils \
    build-essential \
    gawk \
    gettext \
    patch \
    python \
    gcc-multilib \
    texinfo \
    xmlto \
    upx \
    libelf-dev \
    autoconf \
    automake \
    libtool \
    device-tree-compiler \
    g++-multilib \
    ca-certificates"
ENV PKG_DEPS=$PKG_DEPS

# ***** 拷贝文件 *****
COPY ["ps-entry.sh", "/docker-entrypoint.sh"]
COPY ["my.cnf", "/etc/my.cnf"]

# ***** 安装依赖 *****
RUN set -eux && \
   # 修改源地址
   sed -i s#http://*.*ubuntu.com#http://mirrors.aliyun.com#g /etc/apt/sources.list && \
   # 更新源地址并更新系统软件
   apt-get update -qqy && apt-get upgrade -qqy && \
   # 安装依赖包
   apt-get install -qqy --no-install-recommends $PKG_DEPS && \
   rm -rf /var/lib/apt/lists/* && \
   # 更新时区
   ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime && \
   # 更新时间
   echo ${TZ} > /etc/timezone && \
   # 创建mysql用户
   adduser --disabled-password --home /data/mysql --gecos mysql --shell /bin/false mysql && \
   # 更改为zsh
   sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || true && \
   sed -i -e "s/bin\/ash/bin\/zsh/" /etc/passwd && \
   sed -i -e 's/mouse=/mouse-=/g' /usr/share/vim/vim*/defaults.vim && \
   # 创建主目录
   mkdir -p /data && \
   /bin/zsh

# ***** 下载mysql *****
RUN set -eux && \
    wget --no-check-certificate 'https://down.xiaonuo.live/?url=https://downloads.percona.com/downloads/Percona-Server-LATEST/Percona-Server-${MYSQL_VERSION}/binary/tarball/Percona-Server-${MYSQL_VERSION}-Linux.x86_64.glibc2.17.tar.gz' \
    -O ${DOWNLOAD_SRC}/Percona-Server-${MYSQL_VERSION}-Linux.x86_64.glibc2.17.tar.gz && \
    cd /tmp && tar zxvf Percona-Server-${MYSQL_VERSION}-Linux.x86_64.glibc2.17.tar.gz -C /data && \
    mv Percona-Server-${MYSQL_VERSION}-Linux.x86_64.glibc2.17 mysql && \
    mkdir -v /data/mysql/logs && mkdir -v /data/mysql/tmp && \
    chown -R mysql:mysql /data/mysql && chmod -R 775 /data/mysql && \
    chomd 775 /docker-entrypoint.sh && \
    ln -sf /data/mysql/lib/mysql/libjemalloc.so.1 /usr/lib64/libjemalloc.so.1 && \
    ln -sf /data/mysql/lib /data/mysql/lib64 && \
    echo "/data/mysql/lib" >> /etc/ld.so.conf


# ***** 容器信号处理 *****
STOPSIGNAL SIGQUIT

# ***** 监听端口 *****
EXPOSE 3306 33060

# ***** 运行用户 *****
USER mysql

# ***** 工作目录 *****
WORKDIR ["/data/mysql"]

# ***** 挂载目录 *****
VOLUME ["/data/mysql/data"]

# ***** 入口 *****
ENTRYPOINT ["/docker-entrypoint.sh"]

# ***** 执行命令 *****
CMD ["mysqld"]
