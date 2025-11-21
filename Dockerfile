FROM centos:7


RUN sed -i 's|mirror.centos.org|vault.centos.org|g' /etc/yum.repos.d/CentOS-* && \
    sed -i 's|mirrorlist=|#mirrorlist=|g' /etc/yum.repos.d/CentOS-* && \
    sed -i 's|#baseurl=|baseurl=|g' /etc/yum.repos.d/CentOS-*

# 基础环境
RUN yum install -y epel-release && \
    yum install -y \
      gcc gcc-c++ make autoconf \
      wget tar \
      libxml2 libxml2-devel \
      openssl openssl-devel \
      pcre pcre-devel \
      zlib zlib-devel \
      bzip2 bzip2-devel \
      curl curl-devel \
      libjpeg-turbo libjpeg-turbo-devel \
      libpng libpng-devel \
      freetype freetype-devel \
      libmcrypt libmcrypt-devel \
      libzip libzip-devel \
      mariadb-devel \
      libevent libevent-devel \
      which && \
    yum clean all

WORKDIR /usr/local/src

############################
# 1. 安装 Apache 2.4.12
############################
RUN wget https://archive.apache.org/dist/httpd/httpd-2.4.12.tar.gz && \
    tar zxf httpd-2.4.12.tar.gz && \
    cd httpd-2.4.12 && \
    ./configure \
      --prefix=/usr/local/apache2 \
      --enable-so \
      --enable-rewrite \
      --enable-ssl \
      --enable-expires \
      --enable-headers \
      --with-mpm=event && \
    make -j$(nproc) && \
    make install

############################
# 2. 安装 PHP 5.5.25（以 Apache 模块形式）
############################
RUN wget https://museum.php.net/php5/php-5.5.25.tar.gz && \
    tar zxf php-5.5.25.tar.gz && \
    cd php-5.5.25 && \
    ./configure \
      --prefix=/usr/local/php \
      --with-apxs2=/usr/local/apache2/bin/apxs \
      --with-config-file-path=/usr/local/php/etc \
      --with-config-file-scan-dir=/usr/local/php/etc/conf.d \
      --enable-mysqlnd \
      --with-mysqli=mysqlnd \
      --with-pdo-mysql=mysqlnd \
      --with-mysql=mysqlnd \
      --with-openssl \
      --with-zlib \
      --with-curl \
      --with-gd \
      --with-jpeg-dir=/usr \
      --with-png-dir=/usr \
      --with-freetype-dir=/usr \
      --enable-gd-native-ttf \
      --enable-mbstring \
      --with-mcrypt \
      --enable-ftp \
      --enable-sockets \
      --enable-zip \
      --enable-soap \
      --enable-opcache \
      --with-gettext \
      --with-iconv && \
    make -j$(nproc) && \
    make install && \
    mkdir -p /usr/local/php/etc/conf.d

# 拷贝 php.ini 基础模板（后面再挂载你自己的）
RUN cp /usr/local/src/php-5.5.25/php.ini-production /usr/local/php/etc/php.ini

############################
# 3. 安装 PECL event 扩展（可选，与你当前环境一致）
############################
RUN printf "\n" | /usr/local/php/bin/pecl install event-1.10.2 && \
    echo "extension=event.so" > /usr/local/php/etc/conf.d/event.ini || true

############################
# 4. Zend Guard Loader（需要你提供 .so）
############################
# 假设你把 ZendGuardLoader.so 放在构建上下文的 zend/ 目录
COPY ./zend/ZendGuardLoader.so /usr/local/zend/ZendGuardLoader.so

# 创建 conf.d 目录（挂载你的 zend_guard_loader.ini）
RUN mkdir -p /usr/local/php/etc/conf.d

############################
# 5. Web 根目录 + 容器内目录准备
############################
RUN mkdir -p /var/www/html
WORKDIR /var/www/html

############################
# 6. 使用外部挂载的 httpd.conf / php.ini / zend_guard_loader.ini
############################
# 在 docker-compose 里用 volume 覆盖配置

EXPOSE 80

CMD ["/usr/local/apache2/bin/httpd", "-D", "FOREGROUND"]


