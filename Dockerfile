FROM debian:9
MAINTAINER Eduardo Silva <zedudu@gmail.com>

RUN apt-get update && apt-get install -y  \
    procps \
    autoconf \
    automake \
    bzip2 \
    g++ \
    gfortran \
    git \
    gstreamer1.0-plugins-good \
    gstreamer1.0-tools \
    gstreamer1.0-pulseaudio \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-ugly  \
    libatlas3-base \
    libgstreamer1.0-dev \
    libtool-bin \
    make \
    python2.7 \
    python3 \
    python-pip \
    python-yaml \
    python-simplejson \
    python-gi \
    subversion \
    unzip \
    wget \
    build-essential \
    python-dev \
    sox \
    zlib1g-dev && \
    apt-get clean autoclean && \
    apt-get autoremove -y && \
    pip install ws4py==0.3.2 && \
    pip install tornado==4.3 && \
    ln -s /usr/bin/python2.7 /usr/bin/python ; ln -s -f bash /bin/sh

WORKDIR /opt

RUN wget http://www.digip.org/jansson/releases/jansson-2.7.tar.bz2 && \
    bunzip2 -c jansson-2.7.tar.bz2 | tar xf -  && \
    cd jansson-2.7 && \
    ./configure && make -j $(nproc) && make check &&  make install && \
    echo "/usr/local/lib" >> /etc/ld.so.conf.d/jansson.conf && ldconfig && \
    rm /opt/jansson-2.7.tar.bz2 && rm -rf /opt/jansson-2.7

RUN git clone https://github.com/kaldi-asr/kaldi && \
    cd /opt/kaldi/tools && \
    ./extras/install_openblas.sh && \
    make -j $(nproc) && \
    ./install_portaudio.sh && \
    /opt/kaldi/tools/extras/install_mkl.sh && \
    cd /opt/kaldi/src && ./configure --shared && \
    sed -i '/-g # -O0 -DKALDI_PARANOID/c\-O3 -DNDEBUG' kaldi.mk && \
    make clean -j $(nproc) && make -j $(nproc) depend && make -j $(nproc) && \
    cd /opt/kaldi/src/online && make depend -j $(nproc) && make -j $(nproc) && \
    cd /opt/kaldi/src/gst-plugin && sed -i 's/-lmkl_p4n//g' Makefile && make depend -j $(nproc) && make -j $(nproc) && \
    cd /opt && \
    git clone https://github.com/alumae/gst-kaldi-nnet2-online.git && \
    cd /opt/gst-kaldi-nnet2-online/src && \
    sed -i '/KALDI_ROOT?=\/home\/tanel\/tools\/kaldi-trunk/c\KALDI_ROOT?=\/opt\/kaldi' Makefile && \
    make depend -j $(nproc) && make -j $(nproc) && \
    rm -rf /opt/gst-kaldi-nnet2-online/.git/ && \
    find /opt/gst-kaldi-nnet2-online/src/ -type f -not -name '*.so' -delete && \
    rm -rf /opt/kaldi/.git && \
    rm -rf /opt/kaldi/egs/ /opt/kaldi/windows/ /opt/kaldi/misc/ && \
    find /opt/kaldi/src/ -type f -not -name '*.so' -delete && \
    find /opt/kaldi/tools/ -type f \( -not -name '*.so' -and -not -name '*.so*' \) -delete && \
    cd /opt && git clone https://github.com/alumae/kaldi-gstreamer-server.git && \
    rm -rf /opt/kaldi-gstreamer-server/.git/ && \
    rm -rf /opt/kaldi-gstreamer-server/test/

RUN mkdir -p /opt/models && \
    cd models && \
    wget https://phon.ioc.ee/~tanela/tedlium_nnet_ms_sp_online.tgz --no-check-certificate && \
    tar -zxvf tedlium_nnet_ms_sp_online.tgz && \
    rm tedlium_nnet_ms_sp_online.tgz && \
    wget https://raw.githubusercontent.com/alumae/kaldi-gstreamer-server/master/sample_english_nnet2.yaml -P /opt/models && \
    sed -i 's:full-post-processor:#full-post-processor:g' /opt/models/sample_english_nnet2.yaml && \
    sed -i 's:test/models:/opt/models:g' /opt/models/sample_english_nnet2.yaml && \
    sed -i 's:test/models:/opt/models:g' /opt/models/english/tedlium_nnet_ms_sp_online/conf/ivector_extractor.conf && \
    sed -i 's:test/models:/opt/models:g' /opt/models/english/tedlium_nnet_ms_sp_online/conf/online_nnet2_decoding.conf    

RUN pip install futures && apt-get install -y supervisor

COPY start.sh stop.sh /opt/

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

RUN chmod +x /opt/start.sh && \
    chmod +x /opt/stop.sh 

EXPOSE 80

CMD ["/usr/bin/supervisord"]

